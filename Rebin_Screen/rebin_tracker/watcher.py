"""
Watchdog directory monitor for REBIN captures directory.
Monitors WATCH_DIRECTORY for new images, waits for file write settlement,
and triggers Supabase Storage upload and Database insertion.
"""

import os
import time
import shutil
import logging
import threading
from pathlib import Path
from queue import Queue
from typing import Optional

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileCreatedEvent, FileMovedEvent

from config import settings
from parser import parse_capture_filename, WasteModelOutput
from uploader import SupabaseSyncManager

logger = logging.getLogger("rebin_tracker.watcher")


def wait_for_file_settled(file_path: Path, timeout: float = 6.0, check_interval: float = 0.4) -> bool:
    """
    Waits until a file has finished being written by the camera / local model
    by verifying that its file size remains stable over consecutive checks.
    """
    start_time = time.time()
    last_size = -1

    while time.time() - start_time < timeout:
        try:
            if not file_path.exists():
                time.sleep(check_interval)
                continue

            current_size = file_path.stat().st_size
            if current_size > 0 and current_size == last_size:
                logger.debug(f"File {file_path.name} settled (size: {current_size} bytes)")
                return True

            last_size = current_size
        except (OSError, FileNotFoundError):
            pass

        time.sleep(check_interval)

    return file_path.exists() and file_path.stat().st_size > 0


class CaptureHandler(FileSystemEventHandler):
    """Event handler for new files in the capture directory."""

    def __init__(self, processing_queue: Queue):
        super().__init__()
        self.queue = processing_queue

    def on_created(self, event):
        if not event.is_directory:
            self._handle_file(Path(event.src_path))

    def on_moved(self, event):
        if not event.is_directory:
            self._handle_file(Path(event.dest_path))

    def _handle_file(self, path: Path):
        ext = path.suffix.lower()
        if ext in {".jpg", ".jpeg", ".png", ".webp"}:
            # Ignore hidden or temporary files
            if path.name.startswith(".") or path.name.startswith("~"):
                return
            # Ignore files already inside processed directory
            if "processed" in path.parts:
                return

            logger.info(f"[New Capture Detected] {path.name}")
            self.queue.put(path)


class RebinWatcherDaemon:
    """Daemon process that coordinates directory monitoring, queue processing, and Supabase sync."""

    def __init__(self):
        self.watch_dir = settings.WATCH_DIRECTORY
        self.sync_manager = SupabaseSyncManager()
        self.queue: Queue[Path] = Queue()
        self.running = False
        self.worker_thread: Optional[threading.Thread] = None
        self.observer: Optional[Observer] = None

        # Ensure directories exist
        self.watch_dir.mkdir(parents=True, exist_ok=True)
        if settings.POST_UPLOAD_ACTION == "move":
            settings.PROCESSED_DIRECTORY.mkdir(parents=True, exist_ok=True)

    def _worker_loop(self):
        """Worker thread that processes images from the queue sequentially."""
        logger.info("Sync Worker thread started.")
        while self.running:
            try:
                # Fetch next file with 1s timeout to allow clean shutdown
                try:
                    file_path = self.queue.get(timeout=1.0)
                except Exception:
                    continue

                self._process_single_file(file_path)
                self.queue.task_done()

            except Exception as e:
                logger.error(f"Unexpected error in sync worker: {e}", exc_info=True)

        logger.info("Sync Worker thread stopped.")

    def _process_single_file(self, file_path: Path):
        """Processes a single file: wait settle -> parse -> upload -> database insert -> cleanup."""
        if not file_path.exists():
            logger.warning(f"File vanished before processing: {file_path}")
            return

        # 1. Wait for camera write completion
        if not wait_for_file_settled(file_path):
            logger.warning(f"File did not settle in time: {file_path.name}")
            return

        # 2. Parse filename
        parsed: Optional[WasteModelOutput] = parse_capture_filename(file_path)
        if not parsed:
            logger.info(f"Skipping file with unrecognized format: {file_path.name}")
            return

        logger.info(
            f"[Processing] Identified: Waste='{parsed.waste_type}', "
            f"Confidence={parsed.confidence*100:.1f}%, Timestamp='{parsed.raw_timestamp}'"
        )

        # 3. Upload to Storage & Insert to Database
        try:
            public_url, db_data = self.sync_manager.process_and_sync(file_path, parsed)
            logger.info(f"[Sync Completed Successfully] File: {file_path.name} -> URL: {public_url}")

            # 4. Cleanup or Move
            self._handle_cleanup(file_path)

        except Exception as e:
            logger.error(f"[Sync Failed] Error syncing {file_path.name}: {e}", exc_info=True)

    def _handle_cleanup(self, file_path: Path):
        """Deletes or moves the processed capture to save Raspberry Pi disk space."""
        try:
            if settings.POST_UPLOAD_ACTION == "delete":
                if file_path.exists():
                    file_path.unlink()
                    logger.info(f"[Disk Cleanup] Deleted local capture: {file_path.name}")
            elif settings.POST_UPLOAD_ACTION == "move":
                settings.PROCESSED_DIRECTORY.mkdir(parents=True, exist_ok=True)
                dest = settings.PROCESSED_DIRECTORY / file_path.name
                shutil.move(str(file_path), str(dest))
                logger.info(f"[Disk Cleanup] Moved local capture to: {dest}")
        except Exception as e:
            logger.warning(f"[Disk Cleanup Warning] Failed to clean up {file_path.name}: {e}")

    def process_existing_files(self):
        """Queues any existing unhandled capture files in the directory on startup."""
        logger.info(f"Scanning for existing captures in {self.watch_dir}...")
        count = 0
        for item in self.watch_dir.iterdir():
            if item.is_file() and item.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
                if not item.name.startswith(".") and "processed" not in item.parts:
                    self.queue.put(item)
                    count += 1
        if count > 0:
            logger.info(f"Found and queued {count} existing captures.")

    def start(self):
        """Starts the watchdog observer and worker thread."""
        self.running = True

        # Start worker thread
        self.worker_thread = threading.Thread(target=self._worker_loop, daemon=True, name="SyncWorker")
        self.worker_thread.start()

        # Enqueue existing files
        self.process_existing_files()

        # Start watchdog observer
        event_handler = CaptureHandler(self.queue)
        self.observer = Observer()
        self.observer.schedule(event_handler, path=str(self.watch_dir), recursive=False)
        self.observer.start()

        logger.info(f"Watching directory '{self.watch_dir}' for new camera captures...")

    def stop(self):
        """Gracefully stops observer and worker thread."""
        logger.info("Stopping REBIN Watcher Daemon...")
        self.running = False
        if self.observer:
            self.observer.stop()
            self.observer.join(timeout=3.0)
        if self.worker_thread:
            self.worker_thread.join(timeout=3.0)
        logger.info("REBIN Watcher Daemon stopped cleanly.")

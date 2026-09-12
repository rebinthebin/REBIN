#!/usr/bin/env python3
"""
REBIN Camera Watcher & Supabase Sync Daemon.
Main entry point for Raspberry Pi 5 background service.
"""

import sys
import time
import signal
import logging
import argparse
from pathlib import Path

from config import settings
from watcher import RebinWatcherDaemon

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("rebin_tracker.main")


def parse_args():
    parser = argparse.ArgumentParser(
        description="REBIN Camera Watcher and Supabase Image Synchronization Daemon (Raspberry Pi 5)"
    )
    parser.add_argument(
        "--watch-dir",
        type=str,
        default=str(settings.WATCH_DIRECTORY),
        help=f"Directory to watch for capture images (default: {settings.WATCH_DIRECTORY})"
    )
    parser.add_argument(
        "--bin-id",
        type=str,
        default=settings.CURRENT_BIN_ID,
        help=f"Bin identifier (default: {settings.CURRENT_BIN_ID})"
    )
    parser.add_argument(
        "--action",
        type=str,
        choices=["delete", "move"],
        default=settings.POST_UPLOAD_ACTION,
        help=f"Post-upload action for local file (default: {settings.POST_UPLOAD_ACTION})"
    )
    return parser.parse_args()


def main():
    args = parse_args()

    print("=" * 65)
    print("      REBIN RECYCLING - SUPABASE CAMERA SYNC DAEMON      ")
    print("=" * 65)
    print(f"  Bin ID:            {args.bin_id}")
    print(f"  Supabase URL:      {settings.SUPABASE_URL}")
    print(f"  Storage Bucket:    {settings.BUCKET_NAME}")
    print(f"  Watch Directory:   {args.watch_dir}")
    print(f"  Post Action:       {args.action}")
    print("=" * 65)

    daemon = RebinWatcherDaemon()

    # Graceful shutdown handler
    def signal_handler(signum, frame):
        sig_name = signal.Signals(signum).name
        logger.info(f"Received signal {sig_name}. Shutting down gracefully...")
        daemon.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        daemon.start()
        # Keep main thread alive
        while True:
            time.sleep(1.0)
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received. Stopping...")
        daemon.stop()
    except Exception as e:
        logger.critical(f"Fatal daemon crash: {e}", exc_info=True)
        daemon.stop()
        sys.exit(1)


if __name__ == "__main__":
    main()

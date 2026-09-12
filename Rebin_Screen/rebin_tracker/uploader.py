"""
Supabase Storage and Database synchronization module with retry mechanism.
Uploads capture images to Supabase Storage and records metadata into 'bin_images' table.
"""

import os
import sys
import time
import json
import uuid
import mimetypes
import logging
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Tuple, Optional

try:
    from supabase import create_client, Client
    HAS_SUPABASE_SDK = True
except ImportError:
    HAS_SUPABASE_SDK = False

from config import settings
from parser import WasteModelOutput

logger = logging.getLogger("rebin_tracker.uploader")


class SupabaseSyncManager:
    """Manages resilient upload of images to Supabase Storage and database insertions."""

    def __init__(self):
        self.supabase_url = settings.SUPABASE_URL.rstrip("/")
        self.supabase_key = settings.SUPABASE_ANON_KEY
        self.bucket_name = settings.BUCKET_NAME
        self.bin_id = settings.CURRENT_BIN_ID

        logger.info(f"Connecting to Supabase at: {self.supabase_url}")
        self.client: Optional[Any] = None
        if HAS_SUPABASE_SDK:
            try:
                self.client = create_client(self.supabase_url, self.supabase_key)
                logger.info("Supabase Python SDK initialized successfully.")
            except Exception as e:
                logger.warning(f"Could not init Supabase SDK ({e}), falling back to direct REST API.")
                self.client = None
        else:
            logger.info("Supabase SDK not found in environment, using native Supabase REST API.")

    def generate_storage_path(self, parsed: WasteModelOutput) -> str:
        """
        Generates a unique collision-free storage path:
        [bin_id]/[waste_type]_[confidence]_[timestamp]_[uuid4_short].[ext]
        Example: pbin_0001/Plastik_0.85_20260902_163012_a1b2c3d4.jpg
        """
        now_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        unique_token = uuid.uuid4().hex[:8]
        clean_type = parsed.waste_type
        conf_str = f"{parsed.confidence:.2f}"
        ext = parsed.file_extension

        filename = f"{clean_type}_{conf_str}_{now_str}_{unique_token}.{ext}"
        return f"{self.bin_id}/{filename}"

    def upload_to_storage_with_retry(self, local_path: Path, storage_path: str) -> str:
        """
        Uploads local image file to Supabase Storage bucket with exponential backoff retries.
        Returns the Public URL of the uploaded image.
        """
        mime_type, _ = mimetypes.guess_type(str(local_path))
        if not mime_type:
            mime_type = "image/jpeg" if local_path.suffix.lower() in {".jpg", ".jpeg"} else "image/png"

        delay = settings.RETRY_INITIAL_DELAY
        last_exception = None

        for attempt in range(1, settings.MAX_RETRIES + 1):
            try:
                with open(local_path, "rb") as f:
                    file_bytes = f.read()

                logger.info(
                    f"[Storage Upload] Attempt {attempt}/{settings.MAX_RETRIES}: "
                    f"Uploading {local_path.name} -> {self.bucket_name}/{storage_path}"
                )

                if self.client is not None:
                    # 1. Supabase Python SDK Upload
                    self.client.storage.from_(self.bucket_name).upload(
                        path=storage_path,
                        file=file_bytes,
                        file_options={"content-type": mime_type, "upsert": "true"}
                    )
                    public_url = self.client.storage.from_(self.bucket_name).get_public_url(storage_path)
                else:
                    # 2. Native REST API Upload fallback
                    clean_path = storage_path.lstrip("/")
                    upload_url = f"{self.supabase_url}/storage/v1/object/{self.bucket_name}/{clean_path}"
                    headers = {
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                        "Content-Type": mime_type,
                        "x-upsert": "true"
                    }
                    req = urllib.request.Request(upload_url, data=file_bytes, headers=headers, method="POST")
                    with urllib.request.urlopen(req, timeout=10.0) as resp:
                        pass
                    public_url = f"{self.supabase_url}/storage/v1/object/public/{self.bucket_name}/{clean_path}"

                logger.info(f"[Storage Upload Success] Public URL: {public_url}")
                return public_url

            except Exception as exc:
                last_exception = exc
                logger.warning(
                    f"[Storage Upload Warning] Attempt {attempt} failed: {exc}. "
                    f"Retrying in {delay:.1f}s..."
                )
                time.sleep(delay)
                delay *= settings.RETRY_BACKOFF_FACTOR

        raise RuntimeError(
            f"Failed to upload {local_path.name} to storage after {settings.MAX_RETRIES} attempts. Error: {last_exception}"
        )

    def insert_bin_image_record_with_retry(
        self,
        image_url: str,
        waste_type: str,
        confidence: float
    ) -> Dict[str, Any]:
        """
        Inserts row into 'bin_images' table with exponential backoff retries.
        """
        now_iso = datetime.now(timezone.utc).isoformat()
        payload = {
            "bin_id": self.bin_id,
            "image_url": image_url,
            "waste_type": waste_type,
            "confidence": float(confidence),
            "created_at": now_iso
        }

        delay = settings.RETRY_INITIAL_DELAY
        last_exception = None

        for attempt in range(1, settings.MAX_RETRIES + 1):
            try:
                logger.info(
                    f"[Database Insert] Attempt {attempt}/{settings.MAX_RETRIES}: "
                    f"Recording {waste_type} (%{confidence*100:.1f}) for {self.bin_id}"
                )

                if self.client is not None:
                    res = self.client.table("bin_images").insert(payload).execute()
                    row_data = res.data
                else:
                    insert_url = f"{self.supabase_url}/rest/v1/bin_images"
                    body_bytes = json.dumps(payload).encode("utf-8")
                    headers = {
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                        "Content-Type": "application/json",
                        "Prefer": "return=representation"
                    }
                    req = urllib.request.Request(insert_url, data=body_bytes, headers=headers, method="POST")
                    with urllib.request.urlopen(req, timeout=10.0) as resp:
                        row_data = json.loads(resp.read().decode("utf-8"))

                logger.info(f"[Database Insert Success] Row inserted: {row_data}")
                return row_data

            except Exception as exc:
                last_exception = exc
                logger.warning(
                    f"[Database Insert Warning] Attempt {attempt} failed: {exc}. "
                    f"Retrying in {delay:.1f}s..."
                )
                time.sleep(delay)
                delay *= settings.RETRY_BACKOFF_FACTOR

        raise RuntimeError(
            f"Failed to insert database record for {waste_type} after {settings.MAX_RETRIES} attempts. Error: {last_exception}"
        )

    def process_and_sync(self, local_path: Path, parsed: WasteModelOutput) -> Tuple[str, Dict[str, Any]]:
        """
        Complete sync pipeline: Storage upload + DB insert.
        """
        storage_path = self.generate_storage_path(parsed)
        public_url = self.upload_to_storage_with_retry(local_path, storage_path)
        db_data = self.insert_bin_image_record_with_retry(
            image_url=public_url,
            waste_type=parsed.waste_type,
            confidence=parsed.confidence
        )
        return public_url, db_data

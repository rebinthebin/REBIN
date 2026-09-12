#!/usr/bin/env python3
"""
Supabase Database Updater Module for REBIN Recycling System.
Replaces Firebase Firestore with Supabase REST API for occupancy tracking.
"""

import os
import sys
import json
import logging
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from typing import Set, Optional, Dict, Any

# Configure logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("SupabaseUpdater")

EKRAN_ENV_PATH = "/home/rebin/Desktop/Ekran/.env"

def load_env_file(path: str = EKRAN_ENV_PATH) -> Dict[str, str]:
    config = {}
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    config[k.strip()] = v.strip().strip("'").strip('"')
        except Exception as e:
            logger.warning(f"Could not load env file from {path}: {e}")
    return config


class SupabaseBinUpdater:
    """
    Manages live occupancy data in Supabase 'rebins' table for the current recycling bin.
    """
    ALLOWED_MATERIALS: Set[str] = {"plastic", "glass", "metal", "paper"}

    def __init__(
        self,
        supabase_url: Optional[str] = None,
        anon_key: Optional[str] = None,
        bin_id: Optional[str] = None
    ) -> None:
        env_config = load_env_file()
        self.url = (supabase_url or os.environ.get("SUPABASE_URL") or env_config.get("SUPABASE_URL", "")).rstrip("/")
        self.key = anon_key or os.environ.get("SUPABASE_ANON_KEY") or env_config.get("SUPABASE_ANON_KEY", "")
        self.bin_id = bin_id or os.environ.get("BIN_ID") or env_config.get("BIN_ID", "pbin_0001")

        if not self.url or not self.key:
            logger.warning("Supabase URL or Anon Key is missing. Supabase updates will be disabled.")
            self.is_configured = False
        else:
            self.is_configured = True
            logger.info(f"SupabaseBinUpdater initialized for bin: {self.bin_id}")

    def fetch_bin_data(self) -> Optional[Dict[str, Any]]:
        """Fetches the current row for bin_id from the rebins table."""
        if not self.is_configured:
            return None

        query_url = f"{self.url}/rest/v1/rebins?bin_id=eq.{urllib.parse.quote(self.bin_id)}&select=*"
        req = urllib.request.Request(
            query_url,
            headers={
                "apikey": self.key,
                "Authorization": f"Bearer {self.key}",
                "Accept": "application/json"
            }
        )

        try:
            with urllib.request.urlopen(req, timeout=4.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data and len(data) > 0:
                    return data[0]
        except Exception as e:
            logger.warning(f"Failed to fetch bin data from Supabase: {e}")
        return None

    def update_material(self, material: str, increment_value: float = 0.02) -> bool:
        """
        Increments the occupancy for the given material (plastic, glass, metal, paper)
        and updates the 'last_updated' timestamp in Supabase.
        """
        if not self.is_configured:
            logger.warning("Supabase client not configured. Skipping update.")
            return False

        clean_material = material.strip().lower()
        if clean_material not in self.ALLOWED_MATERIALS:
            logger.warning(f"Invalid material '{material}'. Allowed: {self.ALLOWED_MATERIALS}")
            return False

        field_name = f"occupancy_{clean_material}"

        try:
            # 1. Fetch current occupancy
            current_row = self.fetch_bin_data()
            current_val = 0.0
            if current_row and field_name in current_row:
                try:
                    current_val = float(current_row[field_name] or 0.0)
                except (ValueError, TypeError):
                    current_val = 0.0

            # 2. Compute new clamped occupancy value
            new_val = round(min(1.0, max(0.0, current_val + increment_value)), 4)
            now_iso = datetime.now(timezone.utc).isoformat()

            # 3. Patch row in Supabase
            patch_url = f"{self.url}/rest/v1/rebins?bin_id=eq.{urllib.parse.quote(self.bin_id)}"
            payload = {
                field_name: new_val,
                "last_updated": now_iso
            }
            body_bytes = json.dumps(payload).encode("utf-8")

            req = urllib.request.Request(
                patch_url,
                data=body_bytes,
                headers={
                    "apikey": self.key,
                    "Authorization": f"Bearer {self.key}",
                    "Content-Type": "application/json",
                    "Prefer": "return=representation"
                },
                method="PATCH"
            )

            with urllib.request.urlopen(req, timeout=4.0) as resp:
                if resp.status in (200, 204):
                    logger.info(f"Supabase '{self.bin_id}' updated: {field_name} = {new_val*100:.1f}% (+{increment_value*100:.1f}%)")
                    return True
                else:
                    logger.warning(f"Supabase update returned status {resp.status}")
                    return False

        except Exception as e:
            logger.error(f"Error updating Supabase occupancy: {e}")
            return False


if __name__ == "__main__":
    print("[Test] Initializing SupabaseBinUpdater...")
    updater = SupabaseBinUpdater()
    if updater.is_configured:
        print("[Test] Fetching bin data...")
        bin_data = updater.fetch_bin_data()
        print("[Test] Current Bin Data:", bin_data)
        print("[Test] Testing fetch and zero increment...")
        res = updater.update_material("plastic", 0.0)
        print(f"[Test] Update Result: {'SUCCESS' if res else 'FAILED'}")
    else:
        print("[Test] FAILED: Supabase not configured.")

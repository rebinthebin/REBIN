"""
Configuration module for REBIN Camera Watcher and Supabase Sync Daemon.
Loads variables from environment or .env file with sensible defaults.
"""

import os
from dataclasses import dataclass
from pathlib import Path
try:
    from dotenv import load_dotenv
    HAS_DOTENV = True
except ImportError:
    HAS_DOTENV = False

# Automatically load .env if present in current directory or project root
ENV_FILE = Path(__file__).resolve().parent / ".env"
if HAS_DOTENV:
    if ENV_FILE.exists():
        load_dotenv(dotenv_path=ENV_FILE)
    else:
        load_dotenv()
else:
    # Built-in fallback .env parser
    if ENV_FILE.exists():
        try:
            with open(ENV_FILE, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'").strip('"')
                    if k and k not in os.environ:
                        os.environ[k] = v
        except Exception:
            pass


@dataclass(frozen=True)
class Settings:
    SUPABASE_URL: str = os.getenv(
        "SUPABASE_URL",
        "https://spmyeaixfdiohkmmfvgu.supabase.co"
    ).rstrip("/")

    SUPABASE_ANON_KEY: str = os.getenv(
        "SUPABASE_ANON_KEY",
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNwbXllYWl4ZmRpb2hrbW1mdmd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMTY1NzEsImV4cCI6MjEwMTU5MjU3MX0.wcoZ8uYNZa_9Ugp2iZBdtNxCz9lBHR67_V5GK7kuPcA"
    )

    BUCKET_NAME: str = os.getenv("BUCKET_NAME", "rebin-images")
    CURRENT_BIN_ID: str = os.getenv("CURRENT_BIN_ID", "pbin_0001")
    WATCH_DIRECTORY: Path = Path(os.getenv("WATCH_DIRECTORY", "/home/pi/rebin_captures"))

    POST_UPLOAD_ACTION: str = os.getenv("POST_UPLOAD_ACTION", "delete").lower()  # 'delete' or 'move'
    PROCESSED_DIRECTORY: Path = Path(os.getenv("PROCESSED_DIRECTORY", "/home/pi/rebin_captures/processed"))

    MAX_RETRIES: int = int(os.getenv("MAX_RETRIES", "5"))
    RETRY_INITIAL_DELAY: float = float(os.getenv("RETRY_INITIAL_DELAY_SECONDS", "2.0"))
    RETRY_BACKOFF_FACTOR: float = float(os.getenv("RETRY_BACKOFF_FACTOR", "2.0"))


settings = Settings()

"""
Filename parser for REBIN local model capture outputs.
Expected naming convention: [waste_type]_[confidence]_[timestamp].[ext]
Examples:
  - Plastik_0.85_1725283689.jpg
  - Metal_0.73_20260831.jpg
  - Cam_0.92_1725283690.png
  - Kagit_0.80_1725283691.jpg
"""

import re
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

logger = logging.getLogger("rebin_tracker.parser")

# Canonical waste type mapping
WASTE_TYPE_MAP = {
    "plastik": "Plastik",
    "plastic": "Plastik",
    "metal": "Metal",
    "cam": "Cam",
    "glass": "Cam",
    "kagit": "Kağıt",
    "kağıt": "Kağıt",
    "paper": "Kağıt",
    "diger": "Diğer",
    "other": "Diğer",
}


@dataclass
class WasteModelOutput:
    waste_type: str
    confidence: float
    raw_timestamp: str
    original_filename: str
    file_extension: str


def parse_capture_filename(file_path: Path | str) -> Optional[WasteModelOutput]:
    """
    Parses capture filename into waste_type, confidence, and timestamp.
    Returns WasteModelOutput or None if file is not an image or cannot be parsed.
    """
    path = Path(file_path)
    filename = path.name

    # Check extension
    ext = path.suffix.lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        logger.debug(f"Skipping non-image file: {filename}")
        return None

    stem = path.stem  # Filename without extension
    parts = stem.split("_")

    waste_type = "Bilinmiyor"
    confidence = 0.50
    timestamp_str = ""

    if len(parts) >= 3:
        # Standard format: [waste_type]_[confidence]_[timestamp...]
        raw_type = parts[0].strip()
        waste_type = WASTE_TYPE_MAP.get(raw_type.lower(), raw_type.capitalize())

        try:
            confidence = float(parts[1])
            # Clamp confidence between 0.0 and 1.0
            confidence = max(0.0, min(1.0, confidence))
        except (ValueError, TypeError):
            confidence = 0.50
            logger.warning(f"Could not parse confidence '{parts[1]}' in {filename}, defaulting to 0.50")

        # Join remainder as timestamp
        timestamp_str = "_".join(parts[2:])

    elif len(parts) == 2:
        # Format: [waste_type]_[confidence] or [waste_type]_[timestamp]
        raw_type = parts[0].strip()
        waste_type = WASTE_TYPE_MAP.get(raw_type.lower(), raw_type.capitalize())
        try:
            confidence = float(parts[1])
            confidence = max(0.0, min(1.0, confidence))
            timestamp_str = "latest"
        except ValueError:
            timestamp_str = parts[1]
            confidence = 0.75
    else:
        # Single name fallback e.g. Plastik.jpg
        raw_type = stem.strip()
        waste_type = WASTE_TYPE_MAP.get(raw_type.lower(), raw_type.capitalize())
        confidence = 0.70
        timestamp_str = "latest"

    return WasteModelOutput(
        waste_type=waste_type,
        confidence=round(confidence, 4),
        raw_timestamp=timestamp_str,
        original_filename=filename,
        file_extension=ext.lstrip("."),
    )

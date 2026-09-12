"""
Integration and Unit Test Suite for REBIN Camera Sync.
Tests filename parsing, Supabase Storage upload, and Database insertion.
"""

import os
import sys
import tempfile
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

from parser import parse_capture_filename, WasteModelOutput
from uploader import SupabaseSyncManager
from config import settings


def test_filename_parser():
    print("\n--- [Test 1] Filename Parser Tests ---")
    test_cases = [
        ("Plastik_0.85_1725283689.jpg", "Plastik", 0.85),
        ("Metal_0.73_20260831.jpg", "Metal", 0.73),
        ("Cam_0.92_1725283690.png", "Cam", 0.92),
        ("kagit_0.60_20260902_163012.jpg", "Kağıt", 0.60),
        ("plastic_0.99_12345.jpeg", "Plastik", 0.99),
    ]

    all_passed = True
    for filename, expected_type, expected_conf in test_cases:
        res = parse_capture_filename(filename)
        assert res is not None, f"Failed to parse {filename}"
        assert res.waste_type == expected_type, f"Expected {expected_type}, got {res.waste_type}"
        assert abs(res.confidence - expected_conf) < 1e-3, f"Expected {expected_conf}, got {res.confidence}"
        print(f"  [OK] {filename} -> Type: {res.waste_type}, Confidence: {res.confidence*100:.1f}%, Ext: {res.file_extension}")

    print("All filename parser tests PASSED!")
    return all_passed


def test_supabase_connectivity():
    print("\n--- [Test 2] Supabase Connectivity & Live Sync Test ---")
    try:
        manager = SupabaseSyncManager()
    except Exception as e:
        print(f"  [FAIL] Failed to initialize Supabase client: {e}")
        return False

    # Create a dummy 1x1 pixel test JPEG
    # Minimal JPEG header bytes
    dummy_jpeg_bytes = bytes([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
        0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
        0x00, 0xBF, 0x00, 0xFF, 0xD9
    ])

    with tempfile.NamedTemporaryFile(suffix="_Plastik_0.85_test.jpg", delete=False) as tf:
        tf.write(dummy_jpeg_bytes)
        temp_path = Path(tf.name)

    try:
        sample_output = WasteModelOutput(
            waste_type="Plastik",
            confidence=0.85,
            raw_timestamp="test_run",
            original_filename=temp_path.name,
            file_extension="jpg"
        )

        print(f"  Uploading test image '{temp_path.name}' to Supabase Storage '{settings.BUCKET_NAME}'...")
        storage_path = manager.generate_storage_path(sample_output)
        public_url = manager.upload_to_storage_with_retry(temp_path, storage_path)
        print(f"  [OK] Storage Upload Successful! URL: {public_url}")

        print("  Inserting record into 'bin_images' table...")
        db_res = manager.insert_bin_image_record_with_retry(
            image_url=public_url,
            waste_type=sample_output.waste_type,
            confidence=sample_output.confidence
        )
        print(f"  [OK] Database Insert Successful! Record: {db_res}")

        print("\nAll Supabase sync tests PASSED successfully!")
        return True

    except Exception as e:
        print(f"  [FAIL] Live Sync Test Failed: {e}")
        return False
    finally:
        if temp_path.exists():
            temp_path.unlink()


if __name__ == "__main__":
    parser_ok = test_filename_parser()
    if not parser_ok:
        sys.exit(1)

    sync_ok = test_supabase_connectivity()
    if not sync_ok:
        print("\nNote: Supabase live sync test had an issue. Please verify network access and credentials.")
        sys.exit(1)

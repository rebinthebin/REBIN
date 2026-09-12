#!/usr/bin/env python3
"""
REBIN Camera Motion Detector & Kiosk Bridge
Connects the live REBIN AI Camera Detector directly to the Touch Screen Kiosk UI.
"""

import os
import sys

REBIN_DIR = "/home/rebin/Desktop/REBIN"

def main():
    print("=====================================================")
    print("  REBIN Kiosk - Kamera Dedektör Köprüsü Başlatılıyor ")
    print("=====================================================")
    sys.path.insert(0, REBIN_DIR)
    os.chdir(REBIN_DIR)
    
    # Run the real REBIN headless detector (Hailo 8 AI HAT+)
    from headless_hailo import main as detector_main
    detector_main()

if __name__ == "__main__":
    main()

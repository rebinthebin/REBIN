#!/usr/bin/env python3
"""
REBIN Touch Display - Sınıflandırma ve Algılama Simülatörü
Kamera veya yapay zeka olmadan arayüzün sınıflandırma akışını test etmek için kullanılır.
Kullanım:
    python3 simulate_classification.py plastic
    python3 simulate_classification.py glass 0.98
    python3 simulate_classification.py metal 0.91
    python3 simulate_classification.py paper 0.89
    python3 simulate_classification.py unknown
"""

import sys
import json
import urllib.request

def trigger(waste_type="Plastik", confidence=0.96, image_filename="sample_plastic_1.png"):
    url = "http://localhost:8080/api/classify/trigger"
    
    # Map input string
    mapping = {
        "plastic": ("Plastik", "sample_plastic_1.png"),
        "plastik": ("Plastik", "sample_plastic_1.png"),
        "glass": ("Cam", "sample_glass_1.png"),
        "cam": ("Cam", "sample_glass_1.png"),
        "metal": ("Metal", "sample_plastic_1.png"),
        "paper": ("Kağıt", "sample_glass_1.png"),
        "kagit": ("Kağıt", "sample_glass_1.png"),
        "kağıt": ("Kağıt", "sample_glass_1.png"),
        "unknown": ("Bilinmiyor", "sample_plastic_1.png"),
        "error": ("Bilinmiyor", "sample_plastic_1.png")
    }

    key = waste_type.lower()
    if key in mapping:
        waste_type, image_filename = mapping[key]

    payload = {
        "waste_type": waste_type,
        "confidence": float(confidence),
        "image_filename": image_filename,
        "cooldown_duration": 5.0
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

    try:
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print(f"[SUCCESS] Sınıflandırma tetiklendi -> Tür: {waste_type}, Güven: %{int(float(confidence)*100)}")
    except Exception as e:
        print(f"[ERROR] Sunucuya bağlanılamadı ({e}). Lütfen sunucunun (server.py) çalıştığından emin olun.")

if __name__ == "__main__":
    w_type = sys.argv[1] if len(sys.argv) > 1 else "Plastik"
    w_conf = float(sys.argv[2]) if len(sys.argv) > 2 else 0.96
    trigger(w_type, w_conf)

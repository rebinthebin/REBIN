#!/usr/bin/env bash
# =============================================================================
# REBIN Hailo 8 AI HAT+ Kurulum Betiği
# =============================================================================
set -e

echo "[1/4] apt güncelleniyor..."
sudo apt update -q

echo "[2/4] Sistem paketleri kuruluyor..."
sudo apt install -y \
    python3-picamera2 \
    python3-opencv \
    python3-numpy \
    python3-pip \
    python3-serial \
    python3-libgpiod

echo "[3/4] Python paketleri kuruluyor..."
pip3 install --break-system-packages rich

echo "[4/4] Hailo Python SDK kuruluyor..."
# Hailo AI HAT+ için gerekli paket — Raspberry Pi AI HAT+ ile birlikte gelir
# veya https://hailo.ai/developer-zone/ adresinden indirilebilir.
# Resmi kurulum komutu (internet bağlantısı gerektirir):
if python3 -c "import hailo_platform" 2>/dev/null; then
    echo "  hailo_platform zaten kurulu, atlanıyor."
else
    echo "  hailo_platform bulunamadı. Aşağıdaki komutlardan birini deneyin:"
    echo "    pip3 install --break-system-packages hailo-all"
    echo "  Veya Raspberry Pi AI HAT+ resmi kurulum rehberini takip edin:"
    echo "    https://www.raspberrypi.com/documentation/accessories/ai-hat.html"
fi

echo ""
echo "Kurulum tamamlandi."
echo "Test komutu: ./run_hailo.sh headless"
echo "run_hailo.sh'yi çalıştırılabilir yapmayı unutmayın: chmod +x run_hailo.sh"

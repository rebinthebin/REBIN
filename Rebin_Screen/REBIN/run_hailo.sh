#!/usr/bin/env bash
# =============================================================================
# REBIN Hailo 8 AI HAT+ Dedektörü Başlatıcı
# Groq API tamamen kaldırıldı; tüm çıkarım yerel Hailo modeli ile yapılır.
# =============================================================================
export LIBCAMERA_LOG_LEVELS="*:3"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export DISPLAY="${DISPLAY:-:0}"
export PYTHONUNBUFFERED=1

if [ "$1" == "headless" ]; then
    shift
    echo "REBIN Geri Dönüşüm Dedektörü HEADLESS modda başlatılıyor (Hailo 8)..."
    python3 headless_hailo.py "$@"
elif [ "$1" == "gui" ]; then
    shift
    echo "REBIN Geri Dönüşüm Dedektörü GUI modda başlatılıyor (Hailo 8)..."
    python3 gui_hailo.py "$@"
else
    if [ "$1" == "presentation" ]; then
        shift
    fi
    echo "REBIN Sunum Modu başlatılıyor (Kiosk Ekran + Hailo 8 Dedektörü)..."
    exec bash /home/rebin/Desktop/REBIN/start_presentation.sh "$@"
fi

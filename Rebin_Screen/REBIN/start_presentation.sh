#!/usr/bin/env bash
# =============================================================================
# REBIN CANLI SUNUM BAŞLATICI (DOKUNMATİK EKRAN + YAPAY ZEKA DEDEKTÖRÜ)
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBIN_DIR="/home/rebin/Desktop/REBIN"
EKRAN_DIR="/home/rebin/Desktop/Ekran"

# Sistem açılışında masaüstü ve donanımın oturması için kısa bekleme
sleep 1.5

# 1. Ortam Değişkenleri
export LIBCAMERA_LOG_LEVELS="*:3"
export ORT_LOGGING_LEVEL="3"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export DISPLAY="${DISPLAY:-:0}"
export PYTHONUNBUFFERED=1

echo "================================================================="
echo "       REBIN AKILLI GERİ DÖNÜŞÜM SİSTEMİ — SUNUM MODU            "
echo "================================================================="
echo "1. Dokunmatik Arayüz Sunucusu ve Ekran (Kiosk) başlatılıyor..."
echo "2. Supabase Bulut Veritabanı (pbin_0001) aktif."
echo "3. Tekli NIR Kamera (IMX708 NoIR) ve Hailo 8 AI HAT+ (best_rebin.hef) hazır."
echo "================================================================="

# Temizlik: Önceki süreçleri, artık soketleri ve Singleton kilitlerini temizle
pkill -9 -f "headless_hailo.py" 2>/dev/null || true
pkill -9 -f "server.py" 2>/dev/null || true
pkill -9 -f "chromium" 2>/dev/null || true
rm -rf /tmp/org.chromium.Chromium.* /tmp/.org.chromium.Chromium.* 2>/dev/null || true
rm -f /home/rebin/.config/chromium-kiosk/Singleton* 2>/dev/null || true
rm -rf /dev/shm/chromium-kiosk-cache 2>/dev/null || true
mkdir -p /home/rebin/.config/chromium-kiosk /dev/shm/chromium-kiosk-cache

# Elektrik kesintisi veya ani kapanma sonrası Chromium'un beyaz ekranda (about:blank) kalmasını önle
PREFS_FILE="/home/rebin/.config/chromium-kiosk/Default/Preferences"
if [ -f "$PREFS_FILE" ]; then
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREFS_FILE" 2>/dev/null || true
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$PREFS_FILE" 2>/dev/null || true
    sed -i 's/"exit_type":"none"/"exit_type":"Normal"/' "$PREFS_FILE" 2>/dev/null || true
fi

# 2. Ekran Rotasyonunu Uygula
if [ -f "$EKRAN_DIR/setup_display_rotation.sh" ]; then
    bash "$EKRAN_DIR/setup_display_rotation.sh" 2>/dev/null || true
fi

# 3. Kiosk Sunucusunu Başlat
python3 "$EKRAN_DIR/server.py" > /tmp/rebin_server.log 2>&1 &
SERVER_PID=$!

# Sunucunun hazır olmasını bekle (en fazla 15 saniye)
for i in {1..60}; do
    if curl -s --connect-timeout 0.3 http://localhost:8080/api/status > /dev/null 2>&1; then
        echo "[BİLGİ] Dokunmatik ekran sunucusu hazır (http://localhost:8080)."
        break
    fi
    sleep 0.25
done

# 4. Chromium Kiosk'u Başlat (--app ile doğrudan arayüzü açar, çökme kurtarma ekranını atlar)
chromium \
    --kiosk \
    --app=http://localhost:8080 \
    --noerrdialogs \
    --disable-infobars \
    --password-store=basic \
    --disable-session-crashed-bubble \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --disable-client-side-phishing-detection \
    --disable-default-apps \
    --disable-extensions \
    --disable-sync \
    --disable-translate \
    --disable-speech-api \
    --disable-logging \
    --disable-breakpad \
    --safebrowsing-disable-auto-update \
    --check-for-update-interval=31536000 \
    --touch-events=enabled \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --enable-features=OverlayScrollbar \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --ignore-gpu-blocklist \
    --autoplay-policy=no-user-gesture-required \
    --window-size=1280,720 \
    --window-position=0,0 \
    --disk-cache-dir=/dev/shm/chromium-kiosk-cache \
    --user-data-dir=/home/rebin/.config/chromium-kiosk \
    > /dev/null 2>&1 &
BROWSER_PID=$!

echo "[BİLGİ] Kiosk ekranı açıldı."
sleep 1.0

cleanup() {
    echo -e "\n[INFO] Sistem kapatılıyor, süreçler sonlandırılıyor..."
    kill "$BROWSER_PID" 2>/dev/null || true
    pkill -9 -f "chromium" 2>/dev/null || true
    kill "$SERVER_PID" 2>/dev/null || true
    pkill -9 -f "server.py" 2>/dev/null || true
    pkill -9 -f "headless_hailo.py" 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# 5. REBIN Yapay Zeka Algılayıcısını Başlat (Hailo 8 AI HAT+)
cd "$REBIN_DIR"
python3 "$REBIN_DIR/headless_hailo.py" "$@" 2>&1 | tee /tmp/rebin_detector.log

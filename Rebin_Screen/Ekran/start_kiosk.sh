#!/usr/bin/env bash
# =============================================================================
# REBIN Dokunmatik Ekran Kiosk Başlatıcı (Ultra Hızlı Başlatma)
# 1280x720 Yatay Kiosk Arayüzünü ve Arka Plan Sunucusunu Başlatır
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Ensure GUI display environment is set
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export DISPLAY="${DISPLAY:-:0}"

# 1. Ekran Rotasyonunu Uygula (Arka planda paralel)
if [ -f "$DIR/setup_display_rotation.sh" ]; then
    bash "$DIR/setup_display_rotation.sh" 2>/dev/null || true
fi

# 2. Arka Plan Sunucusunu Başlat (Çalışmıyorsa)
if ! pgrep -f "server.py" > /dev/null; then
    python3 "$DIR/server.py" > /tmp/rebin_server.log 2>&1 &
    SERVER_PID=$!
fi

# 3. Sunucunun Hazır Olmasını Hızlıca Kontrol Et (Ultra Düşük Gecikme)
for i in {1..50}; do
    if curl -s --connect-timeout 0.1 http://localhost:8080/api/status > /dev/null 2>&1; then
        break
    fi
    sleep 0.05
done

# 4. Kiosk Modunda Chromium'u En Yüksek Hız Ayarlarıyla Başlat
BROWSER_BIN=""
if command -v chromium > /dev/null 2>&1; then
    BROWSER_BIN="chromium"
elif command -v chromium-browser > /dev/null 2>&1; then
    BROWSER_BIN="chromium-browser"
elif command -v firefox > /dev/null 2>&1; then
    BROWSER_BIN="firefox"
fi

if [ -z "$BROWSER_BIN" ]; then
    exit 1
fi

mkdir -p /home/rebin/.config/chromium-kiosk /dev/shm/chromium-kiosk-cache

if [ "$BROWSER_BIN" == "chromium" ] || [ "$BROWSER_BIN" == "chromium-browser" ]; then
    exec "$BROWSER_BIN" \
        --kiosk \
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
        http://localhost:8080
else
    exec "$BROWSER_BIN" --kiosk http://localhost:8080
fi

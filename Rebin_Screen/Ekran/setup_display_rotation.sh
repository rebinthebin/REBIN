#!/usr/bin/env bash
# =============================================================================
# REBIN Touch Display 2 (5" 720x1280) Permanent Landscape Rotation Setup
# Configures system-level Wayland (kanshi / labwc) & X11 display rotation.
# Usage:
#   ./setup_display_rotation.sh [90|270] (Default: 90)
# =============================================================================

ROTATION="${1:-90}"

echo "================================================================="
echo "  REBIN Dokunmatik Ekran Kalıcı Yatay Rotasyon Yapılandırması ($ROTATION°)"
echo "================================================================="

# 1. Kanshi Kalıcı Yapılandırması (Wayland Otomatik Ekran Yöneticisi)
mkdir -p "$HOME/.config/kanshi"
cat << KANSHI_EOF > "$HOME/.config/kanshi/config"
profile {
	output DSI-1 enable scale 1.000000 mode 720x1280@60.011 position 0,0 transform $ROTATION
	output DSI-2 enable scale 1.000000 mode 720x1280@60.011 position 0,0 transform $ROTATION
}
KANSHI_EOF
echo "[INFO] Kanshi konfigürasyonu güncellendi: $HOME/.config/kanshi/config"

# 2. Labwc Autostart Yapılandırması
mkdir -p "$HOME/.config/labwc"
cat << LABWC_EOF > "$HOME/.config/labwc/autostart"
wlr-randr --output DSI-2 --transform $ROTATION 2>/dev/null &
wlr-randr --output DSI-1 --transform $ROTATION 2>/dev/null &
LABWC_EOF
echo "[INFO] Labwc autostart güncellendi: $HOME/.config/labwc/autostart"

# 3. Anlık Uygulama (Canlı Oturum)
if command -v wlr-randr > /dev/null 2>&1; then
    wlr-randr --output DSI-2 --transform $ROTATION 2>/dev/null || true
    wlr-randr --output DSI-1 --transform $ROTATION 2>/dev/null || true
    echo "[INFO] wlr-randr ile anlık rotasyon uygulandı."
fi

# 4. X11 / Dokunmatik Koordinat Eşlemesi (Fallback)
if command -v xrandr > /dev/null 2>&1; then
    xrandr --output DSI-1 --rotate right 2>/dev/null || xrandr --output DSI-2 --rotate right 2>/dev/null || true
fi

echo "[SUCCESS] Ekran artık sistem açılışında ve her zaman otomatik olarak YATAY ($ROTATION°) modda kalacaktır!"

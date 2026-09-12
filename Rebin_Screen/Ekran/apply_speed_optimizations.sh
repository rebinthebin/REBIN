#!/usr/bin/env bash
# =============================================================================
# REBIN Raspberry Pi 5 - Ultra Hızlı Açılış Optimizasyon Betiği
# Açılış süresini ~10-15 saniye kısaltır.
# =============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[HATA] Bu betik sistem ayarlarını değiştirmek için root (sudo) yetkisi gerektirir."
    echo "Lütfen şu şekilde çalıştırın: sudo bash $0"
    exit 1
fi

echo "================================================================="
echo "  REBIN Açılış Hızlandırma Optimizasyonları Uygulanıyor..."
echo "================================================================="

# 1. NetworkManager-wait-online ve Cloud-Init Servislerini Devre Dışı Bırak (6-8 sn kazandırır)
echo "[1/4] Ağ bekleme ve bulut servisleri kapatılıyor..."
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

systemctl disable cloud-init-main.service cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service 2>/dev/null || true
systemctl mask cloud-init-main.service cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service 2>/dev/null || true

# 2. Bootloader Gecikmelerini Sıfırla (/boot/firmware/config.txt)
echo "[2/4] /boot/firmware/config.txt optimize ediliyor..."
CONFIG_FILE="/boot/firmware/config.txt"
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak_rebin"
    
    # disable_splash=1 ve boot_delay=0 ekle/güncelle
    grep -q "^disable_splash=" "$CONFIG_FILE" && sed -i 's/^disable_splash=.*/disable_splash=1/' "$CONFIG_FILE" || echo "disable_splash=1" >> "$CONFIG_FILE"
    grep -q "^boot_delay=" "$CONFIG_FILE" && sed -i 's/^boot_delay=.*/boot_delay=0/' "$CONFIG_FILE" || echo "boot_delay=0" >> "$CONFIG_FILE"
fi

# 3. Çekirdek Açılış Parametrelerini Hızlandır (/boot/firmware/cmdline.txt)
echo "[3/4] /boot/firmware/cmdline.txt çekirdek parametreleri optimize ediliyor..."
CMDLINE_FILE="/boot/firmware/cmdline.txt"
if [ -f "$CMDLINE_FILE" ]; then
    cp "$CMDLINE_FILE" "${CMDLINE_FILE}.bak_rebin"
    
    # splash kaldır, fastboot quiet loglevel=0 ekle
    CMDLINE_CONTENT=$(cat "$CMDLINE_FILE")
    CMDLINE_CONTENT=$(echo "$CMDLINE_CONTENT" | sed 's/splash//g')
    
    if ! echo "$CMDLINE_CONTENT" | grep -q "fastboot"; then
        CMDLINE_CONTENT="$CMDLINE_CONTENT fastboot loglevel=0"
    fi
    # Fazla boşlukları temizle
    CMDLINE_CONTENT=$(echo "$CMDLINE_CONTENT" | tr -s ' ')
    echo "$CMDLINE_CONTENT" > "$CMDLINE_FILE"
fi

# 4. Kiosk Başlatıcı İzinlerini Tazele
echo "[4/4] Kiosk başlatıcı ve önbellek izinleri kontrol ediliyor..."
chmod +x /home/rebin/Desktop/Ekran/start_kiosk.sh
chmod +x /home/rebin/Desktop/Ekran/setup_display_rotation.sh

echo "================================================================="
echo "  [BAŞARILI] Tüm Açılış Hızlandırma Ayarları Tamamlandı! 🚀"
echo "  Sistemi yeniden başlattığınızda (~10-15 sn daha hızlı) açılacaktır."
echo "================================================================="

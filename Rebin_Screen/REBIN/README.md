# REBIN — Hailo 8 AI HAT+ Yerel Model Geri Dönüşüm Dedektörü

Bu proje, Raspberry Pi 5 üzerinde çalışan, NIR (NoIR / Yakın Kızılötesi) kamera ve **Hailo 8 AI HAT+ (13 TOPS)** donanım hızlandırıcısıyla yerel olarak çalışan akıllı geri dönüşüm malzemesi sınıflandırma sistemidir.

Sistem, kamera önündeki hareketi algılar, hareket durulduğunda `best_rebin.hef` modelini Hailo 8 üzerinde çalıştırır ve malzemenin türünü (Cam, Metal, Plastik, Kağıt) **yerel olarak ve ~5-15 ms** gecikmeyle belirler. Sonucu dokunmatik ekranda animasyonlu ve renk kodlu olarak gösterir, UART üzerinden ESP32'ye iletir ve Supabase bulut veritabanını günceller.

> **Not:** Groq Vision API tamamen kaldırılmıştır. İnternet bağlantısı gerekmez.

---

## Proje Yapısı

```
REBIN/
├── run_hailo.sh            ← Sunum veya headless modunu başlatan ana betik
├── headless_hailo.py       ← Terminal canlı gösterge tablosu ve Hailo 8 kontrolcüsü
├── gui_hailo.py            ← OpenCV tabanlı kamera önizleme modu
├── inference_core.py       ← Kamera yönetimi ve UART haberleşmesini sağlayan modül
├── inference_hailo.py      ← Hareket algılama, Kiosk SSE köprüsü ve Hailo 8 entegrasyonu
├── supabase_updater.py     ← Supabase REST API doluluk güncelleme modülü
├── rebin_detector.service  ← Arka planda servis olarak çalıştırmak için systemd yapılandırması
├── setup.sh                ← Bağımlılıkları kuran kurulum betiği
└── README.md               ← Kullanım kılavuzu (Bu dosya)
```

---

## Kurulum ve Hazırlık

### 1. Bağımlılıkların Kurulması
```bash
cd ~/Desktop/REBIN
chmod +x setup.sh run_hailo.sh
./setup.sh
```

### 2. Hailo Python SDK Kurulumu
Raspberry Pi AI HAT+ ile Hailo Python API'sinin kurulu olması gerekir:
```bash
# Resmi yol (Raspberry Pi OS üzerinde):
pip3 install --break-system-packages hailo-all

# Veya Hailo geliştirici bölgesinden paketi indirin:
# https://hailo.ai/developer-zone/
```

### 3. HEF Model Dosyası
`best_rebin.hef` dosyasının projenin kök dizininde (`~/Desktop/`) veya `REBIN/` klasöründe olduğundan emin olun. Kod her iki konumu da otomatik olarak arar.

### 4. Kameranın Kontrolü
```bash
rpicam-hello --list-cameras
```
Ekranda kameranın (`imx708_wide_noir`) listelenmesi gerekir.

---

## Kullanım Modları

### 1. Sunum Modu (Dokunmatik Ekran Kiosk + AI Dedektörü — Önerilen)
```bash
# Masaüstünden doğrudan başlatma
bash ~/Desktop/start_presentation.sh

# Veya REBIN klasöründen başlatma
./run_hailo.sh
```

### 2. Yalnızca Terminal Modu (Headless)
```bash
./run_hailo.sh headless
```

### 3. Kamera Görüntüleme Modu (GUI)
```bash
./run_hailo.sh gui
```

---

## Çalışma Mantığı ve Parametreler

| Parametre | Açıklama | Varsayılan |
|---|---|---|
| `--hef-path` | `best_rebin.hef` tam yolu | otomatik arama |
| `--conf-threshold` | Tespit güven eşiği (0.0-1.0) | `0.50` |
| `--roi-crop Y1 Y2 X1 X2` | Kameranın odaklanacağı bölge | — |
| `--settle-delay` | Nesne sabitlenmesi bekleme süresi (sn) | `1.5` |
| `--cooldown` | Tespit sonrası bekleme süresi (sn) | `5.0` |
| `--port` | ESP32 seri port yolu | `/dev/ttyACM0` |
| `--still-threshold` | "Hareketsiz" eşiği | `0.015` |
| `--motion-threshold` | Hareket tetikleme eşiği | `0.02` |

---

## ESP32 UART Haberleşme Protokolü
Sistem, tespit edilen malzemeyi **115200 baud rate** hızında UART üzerinden gönderir:
- **Cam (Glass)** → `C`
- **Metal (Metal)** → `M`
- **Plastik (Plastic)** → `P`
- **Kağıt (Paper)** → `K`

---

## Sistem Servisi (Autostart)

```bash
# Servis dosyasını sistem dizinine kopyalayın
sudo cp rebin_detector.service /etc/systemd/system/

# Systemd'yi yenileyin ve servisi aktifleştirin
sudo systemctl daemon-reload
sudo systemctl enable rebin_detector.service
```

### Yönetim Komutları:
| Komut | Açıklama |
|---|---|
| `sudo systemctl start rebin_detector.service` | Servisi başlat |
| `sudo systemctl stop rebin_detector.service` | Servisi durdur |
| `sudo systemctl restart rebin_detector.service` | Servisi yeniden başlat |
| `systemctl status rebin_detector.service` | Çalışma durumunu incele |
| `journalctl -u rebin_detector.service -f` | Canlı logları izle |
| `sudo systemctl disable rebin_detector.service` | Otomatik başlangıcı devre dışı bırak |

---

## Model Hakkında

- **Model dosyası:** `best_rebin.hef`
- **Donanım:** Hailo 8 AI HAT+ (13 TOPS) — Raspberry Pi 5 PCIe üzerinden bağlı
- **Sınıflar:** Glass (Cam), Metal, Paper (Kağıt), Plastic (Plastik)
- **Çıkarım gecikmesi:** ~5-15 ms (Groq API'ye kıyasla ~50-100x daha hızlı)
- **İnternet:** Gerekmez

### Hailo Çıkış Tensor Formatı
`inference_hailo.py` hem YOLOv10 end-to-end (`[1, 300, 6]`) hem de YOLOv8 (`[1, 84, 8400]`) formatlarını otomatik algılar. Model tensorlarını incelemek için:
```bash
hailortcli parse-hef best_rebin.hef
```

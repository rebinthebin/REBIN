# REBIN Camera Watcher & Supabase Image Sync Service (Raspberry Pi 5)

Raspberry Pi 5 üzerinde arka planda sürekli çalışan (systemd daemon servis), yerel görüntü işleme modelinin yakaladığı atık fotoğraflarını anlık olarak izleyen (`watchdog`), Supabase Storage (`rebin-images`) ve Supabase Database (`bin_images`) ile eşzamanlayan modüler Python 3.11+ servisidir.

---

## 1. Mimari ve Çalışma Akışı

```
[Kamera / Model] 
       │
       ▼ Kaydeder: Plastik_0.85_1725283689.jpg
[/home/pi/rebin_captures] (WATCH_DIRECTORY)
       │
       ▼ watchdog (Anlık dosya yakalama & settle check)
[rebin_tracker/watcher.py]
       │
       ├── 1. Dosya adını ayrıştırır: waste_type='Plastik', confidence=0.85
       ├── 2. Supabase Storage'a yükler: pbin_0001/Plastik_0.85_20260902_163012_uuid4.jpg
       ├── 3. Public URL alır: https://.../rebin-images/pbin_0001/...
       ├── 4. 'bin_images' tablosuna INSERT eder
       └── 5. Yerel dosyayı temizler / siler (Disk tasarrufu)
```

---

## 2. Raspberry Pi 5 Kurulum Adımları

### Adım 1: Proje Dizinine Geçin ve Python Sanal Ortamını (venv) Kurun
```bash
cd /home/pi/rebin_tracker

# Sanal ortam oluşturma (Python 3.11+)
python3 -m venv venv

# Sanal ortamı etkinleştirme
source venv/bin/activate

# Gerekli kütüphaneleri yükleme
pip install --upgrade pip
pip install -r requirements.txt
```

### Adım 2: İzleme Klasörünü Oluşturun
```bash
mkdir -p /home/pi/rebin_captures
mkdir -p /home/pi/rebin_captures/processed
```

### Adım 3: Yapılandırma Dosyasını (.env) Kontrol Edin
Proje dizinindeki `.env` dosyasını düzenleyin:
```bash
nano .env
```
Varsayılan değerler:
```ini
SUPABASE_URL=https://spmyeaixfdiohkmmfvgu.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
BUCKET_NAME=rebin-images
CURRENT_BIN_ID=pbin_0001
WATCH_DIRECTORY=/home/pi/rebin_captures
POST_UPLOAD_ACTION=delete
```

---

## 3. Test ve Doğrulama

Sistemi servis olarak kurmadan önce test scripti ile doğrulayın:
```bash
source venv/bin/activate
python test_sync.py
```

Doğrudan konsoldan canlı çalıştırmak için:
```bash
python main.py
```

Yeni bir dosya düştüğünde test etmek için başka bir terminalden:
```bash
cp sample.jpg /home/pi/rebin_captures/Plastik_0.88_1725283689.jpg
```

---

## 4. Systemd Arka Plan Servisi Olarak Kurulum

Raspberry Pi her açıldığında servisin otomatik başlaması için:

```bash
# 1. Servis dosyasını systemd dizinine kopyalayın
sudo cp /home/pi/rebin_tracker/rebin-tracker.service /etc/systemd/system/

# 2. systemd yapılandırmasını yeniden yükleyin
sudo systemctl daemon-reload

# 3. Servisi başlangıçta otomatik başlayacak şekilde etkinleştirin
sudo systemctl enable rebin-tracker.service

# 4. Servisi hemen başlatın
sudo systemctl start rebin-tracker.service
```

### Servis Durumunu ve Canlı Logları İzleme:
```bash
# Servis durumunu kontrol et
sudo systemctl status rebin-tracker.service

# Canlı logları takip et
journalctl -u rebin-tracker.service -f
```

### Servisi Durdurma veya Yeniden Başlatma:
```bash
sudo systemctl restart rebin-tracker.service
sudo systemctl stop rebin-tracker.service
```

---

## 5. Dosya ve Dizin Yapısı

```
rebin_tracker/
├── config.py                 # Ortam değişkenleri ve yapılandırma
├── parser.py                 # Dosya adı ayrıştırma modülü
├── uploader.py               # Supabase Storage & DB yükleme + Retry mekanizması
├── watcher.py                # watchdog dosya sistemi izleyici & işleyici kuyruğu
├── main.py                   # Daemon ana giriş noktası
├── test_sync.py              # Birim ve entegrasyon testleri
├── requirements.txt          # Python bağımlılıkları (supabase, watchdog vb.)
├── rebin-tracker.service     # systemd servis konfigürasyonu
├── .env                      # Aktif ortam değişkenleri
└── README.md                 # Kurulum ve kullanım kılavuzu
```

<div align="center">

# ♻️ R.E.B.İ.N.
### **Akıllı Entegre Atık Yönetim Sistemi**
#### *Recycling Enabled Bin with Intelligence Network*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![React](https://img.shields.io/badge/React-19-61DAFB?style=for-the-badge&logo=react&logoColor=black)](https://react.dev)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry_Pi_5-AI_HAT+-A22846?style=for-the-badge&logo=raspberrypi&logoColor=white)](https://www.raspberrypi.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

> **T.C. Çevre, Şehircilik ve İklim Değişikliği Bakanlığı "Sıfır Atık" standartlarına tam uyumlu,**
> **Raspberry Pi 5 + AI HAT+ tabanlı fiziksel akıllı atık ayrıştırma ünitesi ile web ve mobil yönetim panellerinden oluşan bütünleşik ekosistem.**

</div>

---

## 📋 İçindekiler

1. [Proje Özeti ve Mimari Bakış](#1-proje-özeti-ve-mimari-bakış)
2. [Sistem Bileşenleri](#2-sistem-bileşenleri)
   - [Rebin_Screen — Fiziksel Ünite & Kiosk Yazılımı](#a-rebin_screen--fiziksel-ünite--kiosk-yazılımı)
   - [Rebin_Web — Yönetim Web Paneli](#b-rebin_web--yönetim-web-paneli)
   - [Rebin_Mobile — Kullanıcı Mobil Uygulaması](#c-rebin_mobile--kullanıcı-mobil-uygulaması)
3. [Veritabanı Tasarımı ve Veri Modeli](#3-veritabanı-tasarımı-ve-veri-modeli)
4. [Kamu Sistemleri ve API Entegrasyon Potansiyeli](#4-kamu-sistemleri-ve-api-entegrasyon-potansiyeli)
5. [Kurulum ve Çalıştırma Rehberi](#5-kurulum-ve-çalıştırma-rehberi)
6. [Kütüphaneler ve Lisanslar](#6-kütüphaneler-ve-lisanslar)
7. [Demo ve Teknik Doküman Linkleri](#7-demo-ve-teknik-doküman-linkleri)

---

## 1. Proje Özeti ve Mimari Bakış

### 1.1 Projenin Tanımı

R.E.B.İ.N. (**R**ecycling **E**nabled **B**in with **I**ntelligence **N**etwork), geleneksel çöp kutusunu yapay zeka destekli, ağ bağlantılı ve kentsel yönetimle entegre bir akıllı geri dönüşüm sistemine dönüştürür. Sistem üç temel katmandan oluşur:

| Katman | Bileşen | Teknoloji |
|--------|---------|-----------|
| **Fiziksel Donanım** | Rebin_Screen | Raspberry Pi 5 + AI HAT+ + NIR Kamera |
| **Yönetim Paneli** | Rebin_Web | React + Vite + Leaflet + Supabase |
| **Mobil Uygulama** | Rebin_Mobile | Flutter + TFLite/PyTorch + Supabase |
| **Veri Katmanı** | Supabase | PostgreSQL + Storage + Realtime |

### 1.2 Sıfır Atık Standartları

T.C. Çevre, Şehircilik ve İklim Değişikliği Bakanlığı'nın belirlediği resmi renk kodları sistemin tüm bileşenlerinde kullanılmaktadır:

| Atık Türü | Renk | Hex Kodu | `occupancy_*` Alanı |
|-----------|------|----------|---------------------|
| 🔵 Plastik | Mavi | `#1477d4` | `occupancy_plastic` |
| 🟡 Kağıt | Sarı | `#feb200` | `occupancy_paper` |
| 🟢 Cam | Yeşil | `#41a047` | `occupancy_glass` |
| 🔴 Metal | Kırmızı | `#ef524e` | `occupancy_metal` |

### 1.3 Sistem Mimarisi

```
┌─────────────────────────────────────────────────────────────┐
│               FİZİKSEL ÜNİTE (Raspberry Pi 5)               │
│                                                             │
│  [NIR Kamera] ──► [Hailo 8 AI HAT+]  ──► [UART Motor]      │
│    Picamera2       best_rebin.hef         Kapak Kontrolü    │
│                        │                                    │
│               [supabase_updater.py]                         │
│               occupancy PATCH (+0.02)                       │
│                        │                                    │
│    [Flutter Kiosk UI] ◄─── [Python HTTP Server]             │
│    1280×720 Dokunmatik     SSE Olay Yayını                  │
│                                                             │
│    [rebin-tracker Watchdog Daemon]                          │
│    Dosya İzleme → Supabase Storage Upload                   │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTPS / WSS
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  SUPABASE (Backend as a Service)            │
│                                                             │
│  PostgreSQL Tables:  rebins · bin_images · bin_errors       │
│                      depolar · tesisler                     │
│                                                             │
│  Storage Bucket:  REBIN-IMAGES                              │
│  Realtime:        Postgres Changes Subscription             │
│  SQL Triggers:    check_capacity_increase_limit             │
│                   update_bin_status_on_error                │
└──────────┬──────────────────────────────────────┬───────────┘
           │ Realtime + REST                       │ Realtime + REST
           ▼                                       ▼
┌─────────────────────┐              ┌─────────────────────────┐
│   REBIN_WEB         │              │   REBIN_MOBILE          │
│   React + Vite      │              │   Flutter + Dart        │
│                     │              │                         │
│  • Kutular Listesi  │              │  • Ana Sayfa            │
│  • İnteraktif Harita│              │  • Kamera Tarama        │
│  • Yönetim + Rota   │              │  • Harita               │
│  • Kutu Detayı      │              │  • Görevler             │
│  OSRM Rota API      │              │  • İstatistikler        │
└─────────────────────┘              └─────────────────────────┘
```

---

## 2. Sistem Bileşenleri

---

## A. Rebin_Screen — Fiziksel Ünite & Kiosk Yazılımı

> **Konum:** `Rebin_Screen/`
> **Platform:** Raspberry Pi 5 (Debian Bookworm), Python 3.11+, Flutter (Kiosk)

### Amacı ve İşlevi

Rebin_Screen, fiziksel akıllı atık kutusunun tüm yazılım yığınını barındırır. Kullanıcıya yönelik dokunmatik kiosk arayüzü (Flutter), AI tabanlı sınıflandırma motoru (Python + Hailo 8 AI HAT+) ve Supabase senkronizasyon servisi (Python watchdog) bu bileşende bir arada çalışır.

> ⚠️ **ÖNEMLİ:** `best_rebin.hef` modeli **yalnızca Raspberry Pi 5 üzerindeki Hailo 8 AI HAT+** donanımı ile çalışır. Standart CPU/GPU ortamlarında çalışmaz ve bu platform dışında başlatılamaz.

### Alt Dizin: `REBIN/` — AI Çıkarım Motoru

| Dosya | Açıklama |
|-------|----------|
| `inference_hailo.py` | **Ana AI motoru.** `best_rebin.hef` modelini Hailo 8 AI HAT+ üzerinde çalıştıran `HailoClassifier` sınıfını içerir. YOLOv8/v10 çıkış formatlarını otomatik algılar; ~5–15 ms gecikmeyle cam, metal, kağıt, plastik sınıflandırması yapar. |
| `headless_hailo.py` | **Headless mod kontrolcüsü.** Terminal tabanlı canlı gösterge tablosu ile Hailo AI HAT+ dedektörünü yönetir; Groq/bulut bağımlılığı sıfırdır, tüm çıkarım yerel modelde yapılır. |
| `inference_core.py` | **Ortak altyapı modülü.** ONNX Runtime oturumu yönetimi, Picamera2 kamera başlatma, UARTManager (motor/kapak kontrolü) ve frame-level ön işleme fonksiyonlarını sağlar. |
| `supabase_updater.py` | **Canlı doluluk güncelleyicisi.** Her sınıflandırmada `rebins` tablosundaki ilgili `occupancy_*` alanını `+0.02` artırarak günceller; değeri `[0.0, 1.0]` aralığında tutar ve ISO 8601 timestamp atar. |
| `gui_hailo.py` | Geliştirme ve sunum ortamları için görsel çerçeveli (OpenCV pencereli) GUI modu. |
| `rebin_detector.service` | AI dedektör servisini açılışta otomatik başlatan systemd unit dosyası. |
| `setup.sh` | `picamera2`, `opencv`, `numpy`, `pyserial`, `libgpiod` ve Hailo Python SDK'yı kuran otomatik kurulum betiği. |
| `run_hailo.sh` | Headless veya GUI modunu argümanla başlatan yardımcı betik. |

**Temel Fonksiyonlar (`inference_hailo.py`):**

| Fonksiyon / Sınıf | İşlev |
|-------------------|-------|
| `HailoClassifier.__init__()` | HEF dosyasını bulur, Hailo Runtime (HailoRT) bağlamını açar ve ağırlıkları AI HAT+'a yükler |
| `HailoClassifier.classify()` | Bir veya iki kamera karesi alır; ROI kırpar, ön işler ve HailoRT üzerinden NMS uygulayarak `(material, explanation)` döndürür |
| `_find_hef()` | `best_rebin.hef` dosyasını bilinen konumlarda otomatik arar |
| `SupabaseBinUpdater.update_material()` | Tespit edilen atık türü için Supabase `rebins` tablosunu PATCH metoduyla günceller |

### Alt Dizin: `Ekran/` — Kiosk Kullanıcı Arayüzü

| Dosya | Açıklama |
|-------|----------|
| `server.py` | **Kiosk HTTP sunucusu.** 1280×720 Flutter UI'ya statik dosyaları sunar; `/events` endpoint'i üzerinden SSE (Server-Sent Events) yayınlar; kamera ve sınıflandırma olaylarını gerçek zamanlı olarak kiosk ekranına iletir. `IDLE_TIMEOUT_TO_HOME_SECONDS` parametresiyle otomatik ana ekran dönüşü sağlar. |
| `home_screen.dart` | Kullanıcıyı karşılayan ana kiosk ekranı; bağlı kutunun doluluk oranlarını daire grafikleri ile gösterir ve kullanıcıyı atık bırakmaya yönlendirir. |
| `rebin_detail_screen.dart` | **Sınıflandırma akışını yöneten ekran.** Üç aşamada çalışır: (1) *Bekleme* — kamera aktif; (2) *İşleniyor* — CSS spin animasyonu eşliğinde AI sınıflandırma bekleniyor; (3) *Sonuç* — 10 saniyelik dairesel geri sayım, çekilen fotoğraf ve doğruluk oranı gösterimi. Supabase Realtime ile güncel doluluk bilgilerini canlı alır. |
| `camera_detector_bridge.py` | Hailo AI çıkarım motoru ile kiosk Flutter UI arasında SSE olay köprüsü kurar. |
| `simulate_classification.py` | Gerçek donanım olmaksızın sınıflandırma akışını simüle etmek için geliştirme aracı. |
| `start_kiosk.sh` | Chromium'u tam ekran kiosk modunda başlatan ve servisleri sıralayan otomatik başlatma betiği. |
| `setup_display_rotation.sh` | Raspberry Pi ekranını dikey (portrait) moda döndürmek için yapılandırma betiği. |

### Alt Dizin: `rebin_tracker/` — Watchdog & Supabase Sync Daemon

> Raspberry Pi arka plan servisi: kamera çıktılarını izler, Supabase Storage'a yükler ve `bin_images` tablosuna kayıt açar.

| Dosya | Açıklama |
|-------|----------|
| `main.py` | **Servis giriş noktası.** `--watch-dir`, `--bin-id`, `--action` argümanlarını alır; `RebinWatcherDaemon`'ı başlatır; `SIGINT`/`SIGTERM` sinyallerini yakalayarak temiz kapanma sağlar. |
| `watcher.py` | **Watchdog dosya izleyici.** `watchdog.Observer` ile belirlenen dizini dinler; yeni `.jpg/.png/.webp` dosyası oluştuğunda dosyanın yazımının tamamlanmasını bekler (`wait_for_file_settled`), ardından işlem kuyruğuna ekler. |
| `uploader.py` | **Supabase senkronizasyon yöneticisi.** `SupabaseSyncManager` sınıfı, Supabase Python SDK veya doğrudan REST API üzerinden üstel geri çekilme (exponential backoff) ile Storage yüklemesi ve `bin_images` tablosu kaydı gerçekleştirir. |
| `parser.py` | Dosya adını parse eder; `WasteModelOutput(waste_type, confidence, raw_timestamp, file_extension)` veri yapısını üretir. |
| `config.py` | `.env` dosyasından `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `BUCKET_NAME`, `CURRENT_BIN_ID`, `WATCH_DIRECTORY` ve retry parametrelerini yükleyen frozen dataclass yapısı. |
| `rebin-tracker.service` | Servisi açılışta başlatan, hata durumunda 5 saniyede bir yeniden başlatan systemd unit dosyası. |
| `requirements.txt` | Python bağımlılıkları: `supabase>=2.3.0`, `watchdog>=4.0.0`, `python-dotenv>=1.0.0`, `requests>=2.31.0`. |

---

## B. Rebin_Web — Yönetim Web Paneli

> **Konum:** `Rebin_Web/`
> **Platform:** React 19 + Vite 8 + TailwindCSS + Leaflet
> **Çalıştırma:** `npm run dev` → `http://localhost:5173`

### Amacı ve İşlevi

Rebin_Web, belediye yöneticileri ve saha ekip liderlerine yönelik gerçek zamanlı yönetim panelidir. Tüm Rebin kutularının doluluk durumları, hata kayıtları, depo ve tesis konumları ile araç filo rotaları tek bir arayüzde yönetilir.

### Sayfa ve Bileşen Dosyaları

#### 📄 Sayfalar (`src/pages/`)

| Sayfa | Dosya | Açıklama |
|-------|-------|----------|
| **Kutular** | `KutularPage.jsx` | Sistemdeki tüm Rebin kutularını kart görünümünde listeler. Doluluk oranına (`Kritik ≥%85`, `Yüksek ≥%75`, `Orta ≥%50`, `Düşük <%50`) ve güncelleme tarihine göre çift yönlü filtreleme sunar. QR kodu ile yeni kutu ekleme ve arızalı kutulara "ARIZALI!" rozeti gösterimi içerir. |
| **Harita** | `HaritaPage.jsx` | Leaflet tabanlı interaktif harita. Supabase `depolar` tablosundan çekilen depolar **mavi bina ikonu**, `tesisler` tablosundan çekilen tesisler **yeşil ♻️ ikonu** ile işaretlenir. Kutular doluluk yüzdesine göre renklenir; arızalı kutuların pininde kırmızı `!` rozeti görünür. Şehir ve semt bazlı dinamik filtreleme mevcuttur. |
| **Yönetim** | `YonetimPage.jsx` | **En kapsamlı sayfa.** Harita üzerinde depo bazlı araç filo yönetimi, dolu kutuların rota optimizasyonu (OSRM + Held-Karp DP + 2-Opt + Simulated Annealing) ve anlık araç takip widget'ı içerir. Filo takip paneli ekranın sağ alt köşesinde konumlandırılmıştır. |
| **Kutu Detay** | `BinDetailPage.jsx` | Tek bir kutunun dört atık türü için dairesel doluluk grafikleri, AI sınıflandırma fotoğrafları ve hata kayıtları görüntülenir. Hata türleri: *algılamıyor, sınıflandırmıyor, ayrıştırmıyor, diğer*. Kutunun aktif/pasif durumu toggle ile değiştirilip, saha ekibine görev bildirimi oluşturulabilir. |
| **İletişim** | `IletisimPage.jsx` | Kullanıcı destek ve geri bildirim formu sayfası. |

#### 🧩 Bileşenler (`src/components/`)

| Bileşen | Dosya | Açıklama |
|---------|-------|----------|
| **BinCard** | `BinCard.jsx` | Kutu listesinde her kutu için mini doluluk çubukları, tip etiketi, semt ve arıza durumunu gösteren kart bileşeni. |
| **CircularProgress** | `CircularProgress.jsx` | SVG tabanlı dairesel ilerleme göstergesi; atık türü renklerini otomatik uygular. |
| **CitySelector** | `CitySelector.jsx` | Ankara / İstanbul şehir seçimi için açılır menü; harita ve yönetim sayfalarında paylaşılır. |
| **Navbar** | `Navbar.jsx` | Dört sekme (Kutular, Harita, Yönetim, İletişim) arası gezinti çubuğu. |
| **LoadingSpinner** | `LoadingSpinner.jsx` | Veri yükleme sırasında gösterilen CSS spin animasyonlu yükleme göstergesi. |

#### ⚙️ Servisler (`src/services/`)

| Servis | Dosya | Açıklama |
|--------|-------|----------|
| **Supabase** | `supabase.js` | Tüm Supabase CRUD operasyonlarını kapsayan merkezi servis. `fetchBins()`, `fetchBinById()`, `fetchBinImages()`, `fetchBinErrors()`, `fetchAllDepolar()`, `fetchAllTesisler()`, `fetchDepolarByCity()`, `fetchTesislerByCity()`, `clearBinErrors()`, `insertBin()`, `toggleBinActive()`, `verifyAndAddBin()` fonksiyonlarını içerir. |
| **OSRM** | `osrm.js` | OSRM (Open Source Routing Machine) Table API'sinden NxN gerçek yol seyahat süresi matrisi çeker; `formatDistance()` ve `formatDuration()` yardımcı fonksiyonlarını sunar. |
| **Rota Optimizasyon** | `routeOptimizer.js` | **Çok katmanlı optimizasyon motoru.** `N ≤ 12` durak için Held-Karp Dinamik Programlama (global minimum); 2-Opt Yerel Arama ile çapraz geçiş eliminasyonu; `N > 12` durak için Nearest-Neighbor + 2-Opt + Simulated Annealing. |

---

## C. Rebin_Mobile — Kullanıcı Mobil Uygulaması

> **Konum:** `Rebin_Mobile/`
> **Platform:** Flutter (Dart), Android & iOS
> **Çalıştırma:** `flutter run`

### Amacı ve İşlevi

Rebin_Mobile, bireylerin kendi evlerinden yakındaki Rebin kutularını takip etmelerine, atıklarını kameralarıyla taratarak sınıflandırmalarına, günlük/haftalık görevler tamamlayarak ödül kazanmalarına ve çevresel katkılarını bireysel olarak analiz etmelerine olanak tanır. Uygulama içi yerel model (TFLite / PyTorch Lite) sayesinde **internet bağlantısı olmadan da** atık sınıflandırması yapılabilir.

### Ekranlar (`lib/screens/`)

| Ekran | Dosya | Açıklama |
|-------|-------|----------|
| **Ana Sayfa** | `home_screen.dart` | `privateBinsProvider` ile bağlı Rebin kutularının doluluk oranlarını dairesel göstergelerle listeler; her ekran geçişinde provider'ı yeniler. |
| **Kamera & Tarama** | `camera_screen.dart` | Yerel TFLite ve PyTorch Lite modellerini kullanarak gerçek zamanlı atık sınıflandırması yapar; aktif (canlı frame) ve fotoğraf modlarını destekler; yeşil parlama animasyonuyla tespit anını vurgular. |
| **Sonuç** | `result_screen.dart` | Tarama sonucunu atık türü, güven skoru ve haftalık görev ilerlemesiyle birlikte gösterir; `weeklyTaskProvider`'ı günceller. |
| **Harita** | `map_screen.dart` | `flutter_map` + GPS ile kullanıcının konumuna en yakın Rebin kutularını ve genel geri dönüşüm noktalarını işaretler; nabız animasyonlu konum göstergesi içerir. |
| **Rebin Detay** | `rebin_detail_screen.dart` | Seçilen kutunun dört atık türü için ayrıntılı doluluk grafikleri ve Supabase Realtime ile canlı güncelleme sunar. |
| **QR Tarama** | `qr_scan_screen.dart` | `mobile_scanner` ile Rebin kutusunun QR kodunu okur; kutu ID ve güvenlik kodu doğrulayıp kişisel listeye ekler. |
| **Görevler & Başarılar** | `tasks_screen.dart` | **Günlük ve haftalık görevleri** listeler; `dailyTaskProvider` ve `weeklyTaskProvider` ile tarama sayacını takip eder; görev tamamlandığında 1 GB internet, indirim kuponu gibi ödüllerin kilidini açar. |
| **İstatistikler & Analiz** | `statistics_screen.dart` | `fl_chart` ile bireysel katkı grafikleri sunar; toplam tarama sayısı, kurtarılan CO₂, tasarruf edilen su ve atık türü dağılım tablosunu gösterir. |
| **Bilgi Kartları** | `info_cards_screen.dart` | Her atık kategorisi için kaydırılabilir bilgi kartları; sıfır atık ipuçları ve doğru geri dönüşüm pratiklerini anlatır. |
| **Aktivite** | `activity_screen.dart` | Kullanıcının geçmiş tarama geçmişini kronolojik olarak listeleyen ekran. |
| **Kutularım** | `my_bins_screen.dart` | QR ile eklenen kişisel Rebin kutularının listesi ve hızlı erişim paneli. |
| **Oyunlar** | `games_screen.dart` | Geri dönüşüm temalı mini oyunlar için ekran (geliştirme aşamasında). |

### Servisler (`lib/services/`)

| Servis | Dosya | Açıklama |
|--------|-------|----------|
| **TFLite Servisi** | `tflite_service_mobile.dart` | `tflite_flutter` ile `best_full_integer_quant.tflite` modelini yükler; kamera karesini ön işler ve mobil cihazda yerel çıkarım gerçekleştirir. |
| **PyTorch Servisi** | `pytorch_service.dart` | `pytorch_lite` paketi aracılığıyla alternatif PyTorch modeli çalıştırır; TFLite ile aynı arayüzü paylaşır. |
| **Bin Database** | `bin_database_service.dart` | SQLite (`sqflite`) üzerinde yerel kutu veritabanı yönetimi; Supabase'den senkronize edilen veriler cihazda önbelleğe alınır. |
| **Supabase** | `supabase_service.dart` | `supabase_flutter` SDK'sı üzerinden veri sorgulama ve Realtime aboneliği yönetimi. |
| **Overpass** | `overpass_service.dart` | OpenStreetMap Overpass API'sinden en yakın genel geri dönüşüm noktalarını sorgular. |

---

## 3. Veritabanı Tasarımı ve Veri Modeli

> **Platform:** Supabase (PostgreSQL 15+)

### 3.1 Tablo Şeması

#### `rebins` — Ana Kutu Tablosu

```sql
CREATE TABLE rebins (
  bin_id              TEXT PRIMARY KEY,           -- Örn: "pbin_0001"
  name                TEXT NOT NULL,
  type                TEXT,                        -- "private" | "public"
  is_active           BOOLEAN DEFAULT TRUE,
  status              TEXT DEFAULT 'active',       -- "active" | "out_of_order"
  semt                TEXT,
  latitude            FLOAT8,
  longitude           FLOAT8,
  last_updated        TIMESTAMPTZ DEFAULT NOW(),
  last_emptying       TIMESTAMPTZ,
  occupancy_plastic   FLOAT4 DEFAULT 0.0,          -- 0.0 – 1.0
  occupancy_paper     FLOAT4 DEFAULT 0.0,
  occupancy_glass     FLOAT4 DEFAULT 0.0,
  occupancy_metal     FLOAT4 DEFAULT 0.0,
  qr_image_url        TEXT,
  qr_token            TEXT
);
```

#### `bin_images` — AI Sınıflandırma Fotoğraf Kaydı

```sql
CREATE TABLE bin_images (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bin_id      TEXT REFERENCES rebins(bin_id),
  image_url   TEXT NOT NULL,                       -- Supabase Storage public URL
  waste_type  TEXT NOT NULL,                       -- "plastic" | "paper" | "glass" | "metal"
  confidence  FLOAT4,                              -- 0.0 – 1.0
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

#### `bin_errors` — Donanım Hata Kayıtları

```sql
CREATE TABLE bin_errors (
  bin_id           TEXT PRIMARY KEY REFERENCES rebins(bin_id),
  error_1          INTEGER DEFAULT 0,              -- Malzemeyi algılamıyor
  error_2          INTEGER DEFAULT 0,              -- Malzemeyi sınıflandırmıyor
  error_3          INTEGER DEFAULT 0,              -- Malzemeyi ayrıştırmıyor
  error_4          INTEGER DEFAULT 0,              -- Diğer nedenler
  last_reported_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### `depolar` — Atık Toplama Depo Koordinatları

```sql
CREATE TABLE depolar (
  id         SERIAL PRIMARY KEY,
  depo_adi   TEXT NOT NULL,
  semt       TEXT,
  city       TEXT,                                 -- "Ankara" | "İstanbul"
  latitude   FLOAT8,
  longitude  FLOAT8
);
```

#### `tesisler` — Geri Dönüşüm Tesisi Koordinatları

```sql
CREATE TABLE tesisler (
  id         SERIAL PRIMARY KEY,
  tesis_adi  TEXT NOT NULL,
  semt       TEXT,
  city       TEXT,
  latitude   FLOAT8,
  longitude  FLOAT8
);
```

### 3.2 SQL Trigger'lar ve Güvenlik Kuralları

#### `check_capacity_increase_limit` — Ani Doluluk Artışı Koruyucusu

> Ani düşen atıkların tek seferde %10'dan fazla yalancı kapasite artışı kaydetmesini önler.

```sql
CREATE OR REPLACE FUNCTION check_capacity_increase_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.occupancy_plastic - OLD.occupancy_plastic) > 0.10 THEN
    NEW.occupancy_plastic := OLD.occupancy_plastic + 0.10;
  END IF;
  IF (NEW.occupancy_paper - OLD.occupancy_paper) > 0.10 THEN
    NEW.occupancy_paper := OLD.occupancy_paper + 0.10;
  END IF;
  IF (NEW.occupancy_glass - OLD.occupancy_glass) > 0.10 THEN
    NEW.occupancy_glass := OLD.occupancy_glass + 0.10;
  END IF;
  IF (NEW.occupancy_metal - OLD.occupancy_metal) > 0.10 THEN
    NEW.occupancy_metal := OLD.occupancy_metal + 0.10;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_capacity_increase_limit
BEFORE UPDATE ON rebins
FOR EACH ROW EXECUTE FUNCTION check_capacity_increase_limit();
```

#### `update_bin_status_on_error` — Arıza Durumu Otomatik Tetikleyici

> `bin_errors` tablosuna yeni hata kaydı eklendiğinde ilgili kutunun `status` alanını otomatik `'out_of_order'` yapar.

```sql
CREATE OR REPLACE FUNCTION update_bin_status_on_error()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE rebins SET status = 'out_of_order' WHERE bin_id = NEW.bin_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_bin_status_on_error
AFTER INSERT OR UPDATE ON bin_errors
FOR EACH ROW EXECUTE FUNCTION update_bin_status_on_error();
```

### 3.3 Storage — RLS Politikaları (`REBIN-IMAGES` Bucket)

```sql
-- Herkese okuma izni (Public URL ile erişim)
CREATE POLICY "Allow Public Select"
ON storage.objects FOR SELECT
USING (bucket_id = 'rebin-images');

-- Servislerden yükleme izni
CREATE POLICY "Allow Public Insert"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'rebin-images');
```

### 3.4 Veri Akışı Özeti

```
Hailo AI HAT+ sınıflandırır
       │
       ├─► supabase_updater.py: PATCH rebins SET occupancy_* += 0.02
       │         └─► check_capacity_increase_limit TRIGGER (maks +%10)
       │
       └─► rebin_tracker watchdog fotoğrafı yükler
                 ├─► Storage: rebin-images/{bin_id}/{type}_{conf}_{ts}.jpg
                 └─► INSERT bin_images (image_url, waste_type, confidence)
                              │
                              ▼
                     Supabase Realtime
                  ┌──────┴──────┐
                  ▼             ▼
              Rebin_Web   Rebin_Mobile
```

---

## 4. Kamu Sistemleri ve API Entegrasyon Potansiyeli

### 4.1 Açık Standartlar ve Veri Formatları

- **JSON Payload:** Tüm API yanıtları `Content-Type: application/json` ile sunulur.
- **Zaman Damgaları:** ISO 8601 formatı (`TIMESTAMPTZ`, örn. `2026-09-13T03:21:05+03:00`).
- **Coğrafi Koordinatlar:** WGS84 standardı (`latitude/longitude` float çifti).

### 4.2 Mevcut REST Endpoint'leri (Supabase PostgREST)

```http
# Tüm aktif kutuları listele
GET /rest/v1/rebins?is_active=eq.true&select=*

# Şehre göre depoları filtrele
GET /rest/v1/depolar?city=ilike.Ankara&select=id,depo_adi,latitude,longitude

# Hata kayıtlarını sorgula
GET /rest/v1/bin_errors?bin_id=eq.pbin_0001

# Doluluk güncelle (donanım servisi)
PATCH /rest/v1/rebins?bin_id=eq.pbin_0001
Content-Type: application/json
{ "occupancy_plastic": 0.42, "last_updated": "2026-09-13T00:00:00Z" }
```

### 4.3 Belediye ve CBS Entegrasyon Potansiyeli

| Hedef Sistem | Entegrasyon Yöntemi |
|--------------|---------------------|
| **Sıfır Atık Bilgi Sistemi (SABS)** | Supabase PostgREST REST API → SABS veri giriş endpoint'leri |
| **Coğrafi Bilgi Sistemi (CBS/GIS)** | WGS84 koordinatlar + OGC WFS/WMS uyumlu GeoJSON ihracı |
| **Akıllı Kent Platformları** | MQTT broker entegrasyonu ile `occupancy_*` verileri push |
| **Belediye ERP Sistemleri** | `depolar` ve `tesisler` tablolarından JSON REST export |

---

## 5. Kurulum ve Çalıştırma Rehberi

---

### A. Rebin_Screen — AI Dedektör Servisi (Raspberry Pi 5)

#### Gereksinimler

- Raspberry Pi 5 (8 GB RAM önerilir)
- **Hailo 8 AI HAT+** (PCIe bağlantılı — zorunlu)
- NIR Kamera Modülü (Picamera2 uyumlu)
- Raspberry Pi OS Bookworm (64-bit)
- Python 3.11+

#### 1. Kurulum

```bash
# Projeyi klonla
git clone <repo-url>
cd REBIN/Rebin_Screen/REBIN

# Hailo AI HAT+ ve sistem paketlerini kur
chmod +x setup.sh
./setup.sh

# Hailo Python SDK kurulumu (internet bağlantısı gerektirir)
pip3 install --break-system-packages hailo-all
# Veya: https://www.raspberrypi.com/documentation/accessories/ai-hat.html
```

#### 2. Ortam Değişkenleri

```bash
cp /home/rebin/Desktop/Ekran/.env.example .env
nano .env
```

```dotenv
SUPABASE_URL=https://spmyeaixfdiohkmmfvgu.supabase.co
SUPABASE_ANON_KEY=<your_supabase_anon_key>
BIN_ID=pbin_0001
```

#### 3. AI Dedektörü Başlat

```bash
chmod +x run_hailo.sh

# Headless (terminal) modunda çalıştır
./run_hailo.sh headless

# GUI modunda çalıştır (geliştirme)
./run_hailo.sh gui

# Doğrudan çalıştırma
python3 headless_hailo.py --conf-threshold 0.50 --port /dev/ttyACM0
```

#### 4. Systemd Servisi Olarak Kur

```bash
sudo cp rebin_detector.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable rebin_detector.service
sudo systemctl start rebin_detector.service

# Durum kontrolü
sudo systemctl status rebin_detector.service
```

---

### B. Rebin_Screen — Watchdog & Supabase Sync Daemon

```bash
cd REBIN/Rebin_Screen/rebin_tracker

# 1. Sanal ortam oluştur
python3 -m venv venv
source venv/bin/activate

# 2. Bağımlılıkları yükle
pip install -r requirements.txt

# 3. .env dosyasını yapılandır
cp .env.example .env
nano .env
# SUPABASE_URL, SUPABASE_ANON_KEY, CURRENT_BIN_ID, WATCH_DIRECTORY

# 4. Daemon'ı çalıştır
python main.py --watch-dir /home/pi/rebin_captures --bin-id pbin_0001 --action delete
```

#### Systemd Servisi

```bash
sudo cp rebin-tracker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable rebin-tracker.service
sudo systemctl start rebin-tracker.service

# Log takibi
journalctl -u rebin-tracker.service -f
```

`rebin-tracker.service` dosyası:

```ini
[Unit]
Description=REBIN Camera Watcher & Supabase Image Sync Service (Raspberry Pi 5)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/rebin_tracker
ExecStart=/home/pi/rebin_tracker/venv/bin/python /home/pi/rebin_tracker/main.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

---

### C. Rebin_Screen — Kiosk Arayüzü

```bash
cd REBIN/Rebin_Screen/Ekran

# .env dosyasını yapılandır
cp .env.example .env
nano .env

# Python HTTP sunucusunu başlat
python3 server.py

# Chromium kiosk modunda başlat (ayrı terminal)
chromium-browser --kiosk --noerrdialogs --disable-infobars http://localhost:8080

# Tüm servisleri otomatik başlat
chmod +x start_kiosk.sh
./start_kiosk.sh
```

---

### D. Rebin_Web — Web Yönetim Paneli

#### Gereksinimler

- Node.js 20+
- npm 10+

```bash
cd REBIN/Rebin_Web

# Bağımlılıkları yükle
npm install

# Geliştirme sunucusunu başlat
npm run dev
# → http://localhost:5173

# Üretim build (opsiyonel)
npm run build
npm run preview
```

---

### E. Rebin_Mobile — Flutter Mobil Uygulaması

#### Gereksinimler

- Flutter SDK 3.x (`sdk: ^3.9.0`)
- Android Studio veya Xcode
- Android cihaz/emülatör (Android 7.0+)

```bash
cd REBIN/Rebin_Mobile

# Flutter bağımlılıklarını yükle
flutter pub get

# Bağlı cihazda çalıştır
flutter run

# Android APK build
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Riverpod kod üretimi
dart run build_runner build --delete-conflicting-outputs
```

---

### F. Supabase Kurulumu (Yeni Ortam İçin)

```sql
-- 1. Tabloları oluştur (yukarıdaki şemayı kullanarak)

-- 2. Supabase Dashboard → Storage → New Bucket → "rebin-images" (Public)

-- 3. RLS politikalarını uygula
CREATE POLICY "Allow Public Select" ON storage.objects
  FOR SELECT USING (bucket_id = 'rebin-images');

CREATE POLICY "Allow Public Insert" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'rebin-images');

-- 4. Trigger'ları oluştur (yukarıdaki SQL bloklarını çalıştır)

-- 5. Örnek kutu verisi ekle
INSERT INTO rebins (bin_id, name, type, latitude, longitude, semt)
VALUES ('pbin_0001', 'Test Kutusu', 'private', 41.0082, 28.9784, 'Beşiktaş');
```

---

## 6. Kütüphaneler ve Lisanslar

### Python (Rebin_Screen)

| Kütüphane | Versiyon | Lisans | Kullanım |
|-----------|----------|--------|----------|
| `supabase` | ≥2.3.0 | MIT | Supabase PostgreSQL & Storage SDK |
| `watchdog` | ≥4.0.0 | Apache 2.0 | Dosya sistemi değişiklik izleme |
| `python-dotenv` | ≥1.0.0 | BSD-3 | `.env` ortam değişkeni yükleme |
| `requests` / `urllib3` | ≥2.31.0 | Apache 2.0 | HTTP REST istemci |
| `opencv-python` | Sistem | Apache 2.0 | Görüntü ön işleme |
| `picamera2` | Sistem | BSD-2 | Raspberry Pi kamera sürücüsü |
| `numpy` | Sistem | BSD-3 | Numerik dizi işlemleri |
| `pyserial` | Sistem | BSD-3 | UART motor kontrolü |
| `hailo_platform` | AI HAT+ | Hailo EULA | Hailo 8 NPU çıkarım runtime |
| `onnxruntime` | Sistem | MIT | ONNX fallback çıkarım |

### JavaScript / React (Rebin_Web)

| Kütüphane | Versiyon | Lisans | Kullanım |
|-----------|----------|--------|----------|
| `react` / `react-dom` | ^19.2.8 | MIT | UI framework |
| `vite` | ^8.2.2 | MIT | Build aracı ve dev sunucu |
| `@supabase/supabase-js` | ^2.112.4 | MIT | Supabase istemci SDK |
| `leaflet` | ^1.9.4 | BSD-2-Clause | Harita kütüphanesi |
| `react-leaflet` | ^5.0.0 | Hibrit | React Leaflet entegrasyonu |
| `react-router-dom` | ^7.18.2 | MIT | Client-side routing |
| `lucide-react` | ^1.34.0 | ISC | İkon kütüphanesi |
| `qrcode.react` | ^4.2.0 | MIT | QR kod üretimi |
| `axios` | ^1.20.0 | MIT | HTTP istemcisi |

### Dart / Flutter (Rebin_Mobile)

| Kütüphane | Versiyon | Lisans | Kullanım |
|-----------|----------|--------|----------|
| `supabase_flutter` | ^2.8.0 | MIT | Supabase Flutter SDK |
| `flutter_riverpod` | ^2.5.1 | MIT | State management |
| `go_router` | ^17.2.1 | BSD-3 | Navigasyon / routing |
| `tflite_flutter` | ^0.12.1 | Apache 2.0 | Yerel TFLite model çıkarımı |
| `pytorch_lite` | ^2.0.5 | BSD-3 | PyTorch Lite model çıkarımı |
| `flutter_map` | ^8.3.0 | BSD-3 | Flutter harita bileşeni |
| `camera` | ^0.12.0+1 | BSD-3 | Kamera erişimi |
| `mobile_scanner` | ^7.2.0 | MIT | QR kod tarama |
| `fl_chart` | ^1.2.0 | MIT | Grafik ve istatistik |
| `sqflite` | ^2.4.2 | MIT | Yerel SQLite veritabanı |
| `location` | ^8.0.1 | MIT | GPS konum servisi |
| `google_fonts` | ^8.0.2 | Apache 2.0 | Tipografi |
| `lottie` | ^3.3.3 | MIT | JSON animasyonları |
| `permission_handler` | ^12.0.1 | MIT | İzin yönetimi |

### Proje Lisansı

```
MIT License

Copyright (c) 2026 REBIN Team

Bu yazılımın ve ilgili dokümantasyon dosyalarının ("Yazılım") kopyasını edinen
herhangi bir kişiye, kullanma, kopyalama, değiştirme, birleştirme, yayınlama,
dağıtma, alt lisanslama ve/veya Yazılımın kopyalarını satma hakları dahil olmak
üzere, Yazılım üzerinde herhangi bir kısıtlama olmaksızın işlem yapma izni
ücretsiz olarak verilmektedir.

YAZILIM "OLDUĞU GİBİ" SAĞLANMAKTADIR.
```

---

## 7. Demo ve Teknik Doküman Linkleri

| Kaynak | Bağlantı |
|--------|----------|
| 🎥 Demo Videosu | [YouTube / Drive Demo Linki Buraya] |
| 📦 Android APK | [Release APK İndirme Linki Buraya] |
| 🌐 Canlı Web Demo | [Vercel / Netlify Demo URL Buraya] |
| 📄 Teknik Şartname | [Proje Teknik Şartname PDF Buraya] |

---

<div align="center">

### Sistem Durum Özeti

| Bileşen | Durum |
|---------|-------|
| Rebin_Screen — AI Dedektör (Hailo 8 HAT+) | ✅ Aktif |
| Rebin_Screen — Kiosk UI (Flutter) | ✅ Aktif |
| Rebin_Screen — Watchdog Sync Daemon | ✅ Aktif |
| Rebin_Web — React Yönetim Paneli | ✅ Aktif |
| Rebin_Mobile — Flutter Uygulaması | ✅ Aktif |
| Supabase — PostgreSQL + Storage + Realtime | ✅ Aktif |

---

**R.E.B.İ.N.** — *Daha akıllı bir geri dönüşüm için teknoloji ve donanımı birleştiriyoruz.*

*T.C. Çevre, Şehircilik ve İklim Değişikliği Bakanlığı Sıfır Atık Standartlarına uygun geliştirilmiştir.*

</div>

# REBIN - Entegre Akıllı Atık Yönetim Sistemi ♻️
### *Yapay Zekâ Destekli, Otonom Ayrıştırmalı ve Bulut Entegreli Yeni Nesil Sıfır Atık Ünitesi*

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Hardware: Raspberry Pi 5](https://img.shields.io/badge/Hardware-Raspberry%20Pi%205-c51a4a.svg)](https://www.raspberrypi.com/)
[![NPU: Hailo--8 AI HAT+](https://img.shields.io/badge/NPU-Hailo--8%20(13%20TOPS)-009688.svg)](https://hailo.ai/)
[![Database: Supabase](https://img.shields.io/badge/Database-Supabase%20PostgreSQL-3ecf8e.svg)](https://supabase.com/)
[![Zero Waste Compliant](https://img.shields.io/badge/Standart-T.C.%20Sıfır%20Atık-blue.svg)](https://sifiratik.gov.tr/)

---

## İÇİNDEKİLER
1. [Proje Özeti ve Mimari Bakış](#1-proje-özeti-ve-mimari-bakış)
   - [Projenin Tanımı ve Kapsamı](#projenin-tanımı-ve-kapsamı)
   - [Sıfır Atık Standartları ve Resmi Renk Kodları](#sıfır-atık-standartları-ve-resmi-renk-kodları)
   - [Sistem Mimarisi Şeması](#sistem-mimarisi-şeması)
2. [Sistem Bileşenleri ve Ekran Fonksiyonları (Kullanıcı Kılavuzu)](#2-sistem-bileşenleri-ve-ekran-fonksiyonları-kullanıcı-kılavuzu)
   - [A. Fiziksel Ünite & Donanım Servisi (Raspberry Pi 5 & Hailo-8)](#a-fiziksel-ünite--donanım-servisi-raspberry-pi-5--hailo-8)
   - [B. Dokunmatik Kiosk ve Web Yönetim Paneli](#b-dokunmatik-kiosk-ve-web-yönetim-paneli)
   - [C. Saha ve Yönetici Mobil Uygulaması (Flutter)](#c-saha-ve-yönetici-mobil-uygulaması-flutter)
3. [Veritabanı Tasarımı ve Veri Modeli (Database Schema)](#3-veritabanı-tasarımı-ve-veri-modeli-database-schema)
   - [Tablo Yapıları ve İlişkiler](#tablo-yapıları-ve-ilişkiler)
   - [Aktif SQL Trigger ve Veri Doğrulama Mekanizmaları](#aktif-sql-trigger-ve-veri-doğrulama-mekanizmaları)
   - [Supabase Storage ve RLS Güvenlik Politikaları](#supabase-storage-ve-rls-güvenlik-politikaları)
4. [Kamu Sistemleri ve REST/OGC API Entegrasyon Potansiyeli](#4-kamu-sistemleri-ve-restogc-api-entegrasyon-potansiyeli)
   - [Açık Standartlar ve Veri Formatları](#açık-standartlar-ve-veri-formatları)
   - [Belediye CBS/GIS ve Sıfır Atık Bilgi Sistemi (SABS) Entegrasyonu](#belediye-cbsgis-ve-sıfır-atık-bilgi-sistemi-sabs-entegrasyonu)
5. [Kurulum ve Çalıştırma Rehberi (Installation Guide)](#5-kurulum-ve-çalıştırma-rehberi-installation-guide)
   - [A. Donanım Servisi ve AI Modeli Kurulumu](#a-donanım-servisi-ve-ai-modeli-kurulumu)
   - [B. Dokunmatik Kiosk ve Web Arayüzünün Başlatılması](#b-dokunmatik-kiosk-ve-web-arayüzünün-başlatılması)
   - [C. Arka Plan Sistem Servisleri (systemd)](#c-arka-plan-sistem-servisleri-systemd)
   - [D. Mobil Uygulama Kurulumu](#d-mobil-uygulama-kurulumu)
6. [Kütüphaneler ve Lisanslar (Dependencies & Licensing)](#6-kütüphaneler-ve-lisanslar-dependencies--licensing)
7. [Demo Videosu ve Teknik Doküman Linkleri](#7-demo-videosu-ve-teknik-doküman-linkleri)

---

## 1. PROJE ÖZETİ VE MİMARİ BAKIŞ

### Projenin Tanımı ve Kapsamı
**REBIN**, modern kentsel alanlarda kaynağında ayrıştırma verimini maksimize etmek amacıyla geliştirilmiş, **Raspberry Pi 5** mikrobilgisayarı ve **Hailo-8 AI HAT+ (13 TOPS)** yapay zekâ hızlandırıcısı üzerinde çalışan otonom bir akıllı geri dönüşüm istasyonudur. 

Fiziksel atık ünitesi; çift kamera açısı, anlık hareket algılama sensörleri, mekanik ayrıştırma kapakları ve servo motorlar ile donatılmıştır. Üniteye bırakılan atıklar yerel sinir ağı modeliyle nanosaniyeler mertebesinde sınıflandırılır, mekanik kapak otonom açılarak doğru atık haznesine yönlendirilir ve sonuçlar eşzamanlı olarak **Supabase Bulut Veritabanı** ve **Dokunmatik Kiosk Ekranı** ile senkronize edilir. 

Saha ekipleri ve belediye atık yönetim merkezleri; web tabanlı merkezi yönetim paneli ve mobil saha uygulaması üzerinden konteyner doluluk oranlarını, arıza kayıtlarını, atık fotoğraflarını ve dinamik toplama rotalarını anlık olarak takip edebilir.

### Sıfır Atık Standartları ve Resmi Renk Kodları
Proje, **T.C. Çevre, Şehircilik ve İklim Değişikliği Bakanlığı Sıfır Atık Yönetmeliği** tasarım ilkelerine ve kurumsal renk kodlarına tam uyumlu olarak geliştirilmiştir:

| Atık Türü | Renk Adı | HEX Kodu | RGB Değeri | Açıklama / Hedef Malzemeler |
|:---|:---|:---:|:---:|:---|
| 🥤 **Plastik** | Mavi | `#1477D4` | `rgb(20, 119, 212)` | PET şişeler, ambalaj kapları, naylon, HDPE kutular |
| 📦 **Kağıt** | Sarı | `#FEB200` | `rgb(254, 178, 0)` | Karton kutular, gazete/dergi, ofis kağıtları, mukavva |
| 🍸 **Cam** | Yeşil | `#41A047` | `rgb(65, 160, 71)` | Cam şişeler, kavanozlar, meşrubat camları |
| 🥫 **Metal** | Kırmızı | `#EF524E` | `rgb(239, 82, 78)` | Alüminyum içecek kutuları, konserve tenekeleri, kapaklar |

---

### Sistem Mimarisi Şeması

```mermaid
flowchart TD
    subgraph DONANIM ["1. Fiziksel Donanım Katmanı (Raspberry Pi 5)"]
        Cam["📷 IMX708 NoIR Kamera"] --> |Canlı Video / Kare| Det["🏃 MotionDetector (OpenCV BGS)"]
        Det --> |Hareket Kararlı| NPU["⚡ Hailo-8 AI HAT+ (best_rebin.hef)"]
        NPU --> |Sınıflandırma: Plastik/Cam/Metal/Kağıt| Controller["🧠 HailoDetectorController"]
        Controller --> |UART Seri Haberleşme| ESP["⚙️ ESP32 / Servo Motor & Mekanik Kapaklar"]
        Controller --> |Kare Kaydı| Captures["📁 /home/pi/rebin_captures"]
    end

    subgraph SYNC_SERVİSLERİ ["2. Arka Plan Servisleri & İletişim"]
        Captures --> |Dosya İzleme / Event| Watcher["👀 rebin_tracker (Watchdog Daemon)"]
        Watcher --> |HTTP Rest API| SupaStorage["☁️ Supabase Storage (REBIN-IMAGES)"]
        Watcher --> |Metadata Insert| SupaDB["🗄️ Supabase PostgreSQL"]
        Controller --> |Doluluk Güncelleme| SupaDB
        Bridge["🌉 camera_detector_bridge / server.py"] --> |SSE / REST (Port 8080)| KioskUI["🖥️ 1280x720 Dokunmatik Kiosk Ekranı"]
    end

    subgraph BULUT_KATMANI ["3. Supabase Bulut & Veri Yönetimi"]
        SupaDB --> Triggers["⚡ SQL Triggers & RLS Güvenlik Kuralları"]
        Triggers --> Tables[("rebins / bin_images / bin_errors / depolar / tesisler")]
    end

    subgraph YONETIM_KATMANI ["4. İzleme & Kullanıcı Arayüzleri"]
        Tables --> |Realtime WebSocket / REST| WebDash["🌐 Web Yönetim Paneli (YonetimPage & Harita)"]
        Tables --> |Supabase Flutter SDK| MobileApp["📱 Mobil Uygulama (Saha Ekibi & Yönetici)"]
        Tables --> |Açık REST / OGC API| KamuCBS["🏛️ Belediye CBS / Sıfır Atık Bilgi Sistemi (SABS)"]
    end
```

---

## 2. SİSTEM BİLEŞENLERİ VE EKRAN FONKSİYONLARI (Kullanıcı Kılavuzu)

### A. Fiziksel Ünite & Donanım Servisi (Raspberry Pi 5 & Hailo-8)
Kaynak kod dizini: `REBIN/` ve `rebin_tracker/`

1. **Uçta Yapay Zekâ Çıkarımı (Hailo-8 AI HAT+):**
   - `inference_hailo.py` içerisindeki `HailoClassifier` sınıfı, `best_rebin.hef` modelini doğrudan 13 TOPS kapasiteli Hailo-8 NPU üzerinde koşturur.
   - Herhangi bir harici bulut API bağımlılığı olmaksızın **~5-15 ms** çıkarım süresiyle çalışır; internet kesilse dahi ünite tam otonom işlemeye devam eder.
   - Model girdi boyutu $640 \times 640 \times 3$ BGR formatıdır. YOLO mimarisiyle eğitilmiş model, `glass`, `metal`, `paper`, `plastic` sınıflarını güven skoruyla tespit eder.

2. **Hareket ve Kararlılık Algılama (MotionDetector):**
   - OpenCV tabanlı arka plan farkı (Background Subtraction) algoritması ile nesne tepsiye konulduğunda hareket fark edilir (`OBJECT_PLACING` durumu).
   - Nesne hareketsizleştiğinde (`settle_delay: 1.5s`), model çıkarımı tetiklenir ve gereksiz kare işlemenin önüne geçilir.

3. **Mekanik Kapak ve Donanım Kontrolü (UART & GPIO):**
   - Sınıflandırma sonucu `UARTManager` üzerinden mikrodenetleyiciye (ESP32) tek baytlık kontrol komutu olarak aktarılır:
     * `'C'` $\rightarrow$ Cam (Glass) kapağı açılır
     * `'M'` $\rightarrow$ Metal kapağı açılır
     * `'P'` $\rightarrow$ Plastik (Plastic) kapağı açılır
     * `'K'` $\rightarrow$ Kağıt (Paper) kapağı açılır
   - Atık hazneye düştükten sonra 5 saniyelik mekanik soğuma süresi (`COOLDOWN`) işletilir ve sistem bir sonraki kullanıcı için hazır duruma geçer (`WAIT_FOR_OBJECT`).

4. **Klasör İzleme ve Otomatik Senkronizasyon (`rebin_tracker`):**
   - `watcher.py` (Watchdog kütüphanesi) `/home/pi/rebin_captures` klasörüne yazılan atık fotoğraflarını anında yakalar.
   - `uploader.py`, çekilen fotoğrafları üstel geri çekilme (exponential backoff retry) algoritmasıyla `REBIN-IMAGES` Supabase Storage bucket'ına yükler, elde ettiği güvenli genel linki `bin_images` tablosuna kayıt eder ve yerel kopyayı temizler.

5. **Donanım Sağlık Kontrolü (Heartbeat) ve Hata Bildirimi:**
   - Kamera veya donanım arızalarında, sensör okuma problemlerinde otomatik hata yakalama devreye girer.
   - Hatalar Supabase `bin_errors` tablosuna atomik olarak sayaç artırımı yapılarak iletilir.

---

### B. Dokunmatik Kiosk ve Web Yönetim Paneli
Kaynak kod dizini: `Ekran/` (Python HTTP + SSE Server, Vanilla HTML5/CSS3/JS Kiosk UI)

1. **Canlı Durum Akışı:**
   - **Bekleme Ekranı (Waiting):** Kullanıcıyı karşılayan, atık tepsisine malzeme bırakılmasını yönlendiren interaktif animasyonlu ekran.
   - **Analiz Ekranı (Processing):** Malzeme algılandığında devreye giren modern CSS spin animasyonu ve "Yapay Zekâ Analiz Ediyor..." durum bildirimi.
   - **Sonuç ve Geri Sayım Ekranı (Result):** Modelin tespit ettiği atık türünün resmi Sıfır Atık rengiyle vurgulandığı, tespit edilen doğruluk oranının (%96 vb.) ve çekilen kameranın anlık gösterildiği ekran. 10 saniyelik dairesel SVG geri sayım çubuğu ile yönlendirme kapakları senkronize gösterilir.

2. **İnteraktif Harita Entegrasyonu (Leaflet & Supabase):**
   - Supabase üzerindeki `depolar` (Mavi İşaretçi - Lojistik Merkezleri) ve `tesisler` (Yeşil İşaretçi - Geri Dönüşüm İşleme Tesisleri) koordinat bazlı dinamik harita üzerinde gösterilir.
   - Konteynerlerin anlık doluluk durumları renkli halka grafiklerle işaretçi üzerinde gösterilir.

3. **Bölgesel Filtreleme:**
   - İl (örneğin Ankara / İstanbul) ve Semt bazlı dinamik dropdown filtreleme sayesinde filo yöneticileri yalnızca ilgili sahadaki kutu ve tesisleri görüntüleyebilir.

4. **Canlı Filo Takip ve Kontrol Widget'ı:**
   - Arayüzün sağ alt köşesinde konumlandırılmış hareketli araç takip paneli üzerinden sahada devriyede olan atık toplama araçlarının anlık konumları ve vardiya durumları izlenebilir.

5. **Arıza & Kapasite Güvenlik Paneli:**
   - Ünitede herhangi bir mekanik sıkışma, sensör arızası veya kapak problemi oluştuğunda sarı temalı belirgin **"ARIZALI!"** durum rozeti belirir; kiosk ekranı kullanıcıyı bilgilendirerek güvenlik moduna geçer.

---

### C. Saha ve Yönetici Mobil Uygulaması (Flutter)
Kaynak kod dizini: `Ekran/home_screen.dart`, `Ekran/rebin_detail_screen.dart`, `models/`, `providers/`

1. **Bölge Bazlı Atık Toplama Rotası:**
   - `latlong2` ve harita kütüphaneleriyle saha personeline doluluk oranı kritik (%80 üzeri) seviyeye ulaşan kutuları kapsayan optimize edilmiş boşaltma rotası sunulur.

2. **Dinamik Doluluk Takibi ve Tahmin Grafikleri:**
   - `percent_indicator` bileşeni ile her konteynerin plastik, kağıt, cam ve metal haznelerinin anlık doluluk oranları gösterilir.
   - Kullanıcıların ve teknisyenlerin kutu bazında geçmişe dönük atık fotoğraflarını inceleyebileceği modal galeri (`binImagesProvider`).
   - Saha personeli tarafından tek dokunuşla problem bildirimi (`_showErrorReportModal` $\rightarrow$ `bin_errors` tablosuna anlık kayıt).

---

## 3. VERİTABANI TASARIMI VE VERİ MODELİ (Database Schema)

Sistem, **Supabase PostgreSQL** mimarisi üzerinde ilişkisel ve yüksek performanslı bir şema kullanır.

```
                    ┌─────────────────────────┐
                    │         rebins          │
                    ├─────────────────────────┤
                    │ bin_id (PK, text)       │<───┐
                    │ name (text)             │    │
                    │ is_active (boolean)     │    │
                    │ occupancy_glass (float) │    │
                    │ occupancy_metal (float) │    │
                    │ occupancy_paper (float) │    │
                    │ occupancy_plastic(float)│    │
                    │ processing_status (text)│    │
                    │ latitude, longitude     │    │
                    │ last_emptying, updated  │    │
                    └─────────────────────────┘    │
                                 │                 │
             ┌───────────────────┼─────────────────┤
             ▼                   ▼                 ▼
   ┌───────────────────┐ ┌───────────────┐ ┌───────────────┐
   │    bin_images     │ │  bin_errors   │ │    depolar    │
   ├───────────────────┤ ├───────────────┤ ├───────────────┤
   │ id (uuid, PK)     │ │ id (uuid, PK) │ │ id (uuid, PK) │
   │ bin_id (FK)       │ │ bin_id (FK)   │ │ depo_adi      │
   │ image_url (text)  │ │ error_1 (int) │ │ semt, city    │
   │ waste_type (text) │ │ error_2 (int) │ │ lat, long     │
   │ confidence (float)│ │ error_3 (int) │ └───────────────┘
   │ created_at (timest│ │ error_4 (int) │
   └───────────────────┘ │ last_reported │
                         └───────────────┘
```

### Tablo Yapıları ve İlişkiler

#### 1. `rebins` Tablosu
| Kolon | Tip | Açıklama |
|:---|:---|:---|
| `bin_id` | `TEXT PRIMARY KEY` | Kutu tekil kimliği (Örn: `pbin_0001`) |
| `name` | `TEXT` | Konteyner tanımı / lokasyon ismi |
| `is_active` | `BOOLEAN` | Kutu servis dışı veya aktiflik durumu |
| `occupancy_glass` | `FLOAT` | Cam bölmesi doluluk yüzdesi ($0.00 - 1.00$) |
| `occupancy_metal` | `FLOAT` | Metal bölmesi doluluk yüzdesi ($0.00 - 1.00$) |
| `occupancy_paper` | `FLOAT` | Kağıt bölmesi doluluk yüzdesi ($0.00 - 1.00$) |
| `occupancy_plastic`| `FLOAT` | Plastik bölmesi doluluk yüzdesi ($0.00 - 1.00$) |
| `processing_status`| `TEXT` | Anlık durum (`waiting`, `processing`, `result`) |
| `latitude`, `longitude` | `FLOAT` | WGS84 coğrafi koordinatlar |
| `last_emptying` | `TIMESTAMPTZ` | Son çöp boşaltma tarihi |
| `last_updated` | `TIMESTAMPTZ` | Son sensör / durum güncelleme zamanı |

#### 2. `bin_images` Tablosu
| Kolon | Tip | Açıklama |
|:---|:---|:---|
| `id` | `UUID PRIMARY KEY` | Otomatik oluşturulan tekil kayıt kimliği |
| `bin_id` | `TEXT REFERENCES rebins(bin_id)` | İlişkili kutu kimliği |
| `image_url` | `TEXT` | Supabase Storage genel erişim linki |
| `waste_type` | `TEXT` | Model tarafından tespit edilen malzeme türü |
| `confidence` | `FLOAT` | Yapay zekâ modelinin güven skoru ($0.00 - 1.00$) |
| `created_at` | `TIMESTAMPTZ` | Fotoğrafın çekildiği ve kaydedildiği an |

#### 3. `bin_errors` Tablosu
| Kolon | Tip | Açıklama |
|:---|:---|:---|
| `bin_id` | `TEXT PRIMARY KEY` | Hata kaydının ait olduğu konteyner |
| `error_1` | `INTEGER` | Malzeme algılanamadı hatası sayacı |
| `error_2` | `INTEGER` | Sınıflandırma başarısız hatası sayacı |
| `error_3` | `INTEGER` | Mekanik kapak ayrıştırma hatası sayacı |
| `error_4` | `INTEGER` | Diğer donanım / sensör arızaları |
| `last_reported_at`| `TIMESTAMPTZ` | Son hata bildirim zamanı |

#### 4. `depolar` & `tesisler` Tabloları
- **`depolar`:** Lojistik araç merkezleri ve konteyner yedek depoları (`id`, `depo_adi`, `semt`, `city`, `latitude`, `longitude`).
- **`tesisler`:** Malzemenin ayrıştırılıp ekonomiye kazandırıldığı lisanslı geri dönüşüm tesisleri (`id`, `tesis_adi`, `semt`, `city`, `latitude`, `longitude`).

---

### Aktif SQL Trigger ve Veri Doğrulama Mekanizmaları

#### 1. Ani Kapasite Sıçraması Koruması (`check_capacity_increase_limit`)
Ultrasonik veya optik sensörlerin önüne dik düşen büyük atıkların sahte "Kutu %100 Doldu" alarmı üretmesini engellemek için yazılmış `BEFORE UPDATE` veritabanı tetikleyicisidir:

```sql
CREATE OR REPLACE FUNCTION check_capacity_increase_limit()
RETURNS TRIGGER AS $$
BEGIN
    -- Tek bir atım işleminde doluluk oranı bir önceki değerden en fazla %10 artabilir
    IF (NEW.occupancy_plastic - OLD.occupancy_plastic > 0.10) THEN
        NEW.occupancy_plastic := OLD.occupancy_plastic + 0.05;
    END IF;
    IF (NEW.occupancy_glass - OLD.occupancy_glass > 0.10) THEN
        NEW.occupancy_glass := OLD.occupancy_glass + 0.05;
    END IF;
    IF (NEW.occupancy_metal - OLD.occupancy_metal > 0.10) THEN
        NEW.occupancy_metal := OLD.occupancy_metal + 0.05;
    END IF;
    IF (NEW.occupancy_paper - OLD.occupancy_paper > 0.10) THEN
        NEW.occupancy_paper := OLD.occupancy_paper + 0.05;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_capacity_guard
BEFORE UPDATE ON rebins
FOR EACH ROW EXECUTE FUNCTION check_capacity_increase_limit();
```

#### 2. Otomatik Arıza Durum Tetikleyicisi (`update_bin_status_on_error`)
Bir kutuda biriken hata sayısı eşik değeri aştığında `rebins` tablosundaki `is_active` durumunu otomatik olarak `FALSE` yapar:

```sql
CREATE OR REPLACE FUNCTION update_bin_status_on_error()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.error_1 + NEW.error_2 + NEW.error_3 + NEW.error_4 >= 5) THEN
        UPDATE rebins SET is_active = FALSE WHERE bin_id = NEW.bin_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bin_error_status
AFTER INSERT OR UPDATE ON bin_errors
FOR EACH ROW EXECUTE FUNCTION update_bin_status_on_error();
```

---

### Supabase Storage ve RLS Güvenlik Politikaları
`REBIN-IMAGES` depolama kovası (bucket) üzerinde çalışan Row Level Security (RLS) kuralları:
- **Public Select (Görüntüleme İzni):** Web yönetim paneli ve mobil uygulamanın fotoğrafları yetkilendirme başlığı taşımadan doğrudan CDN üzerinden hızlıca görüntüleyebilmesi için:
  ```sql
  CREATE POLICY "Allow Public Select" 
  ON storage.objects FOR SELECT 
  USING (bucket_id = 'rebin-images');
  ```
- **Public Insert (Yükleme İzni):** Donanım ünitesinin sahada anonim token ile çekilen kareleri doğrudan yükleyebilmesi için:
  ```sql
  CREATE POLICY "Allow Public Insert" 
  ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id = 'rebin-images');
  ```

---

## 4. KAMU SİSTEMLERİ VE REST/OGC API ENTEGRASYON POTANSİYELİ

### Açık Standartlar ve Veri Formatları
Sistem, kamu kurumlarının mevcut akıllı şehir platformlarıyla doğrudan konuşabilecek standart veri formatlarına sahiptir:
- **JSON Payload Mimarisi:** Tüm veri alışverişi hafif ve evrensel JSON veri yapısıyla yürütülür.
- **ISO 8601 Zaman Standardı:** Tüm loglar, çöp döküm ve güncelleme zamanları `YYYY-MM-DDTHH:MM:SSZ` evrensel zaman formatında UTC olarak damgalanır.
- **WGS84 Standart Koordinatlar (EPSG:4326):** Tüm konum bilgileri uluslararası haritacılık ve GPS standardı olan enlem ve boylam formatında saklanır.

### Belediye CBS/GIS ve Sıfır Atık Bilgi Sistemi (SABS) Entegrasyonu
- **Sıfır Atık Bilgi Sistemi (SABS):** Çevre, Şehircilik ve İklim Değişikliği Bakanlığı'nın yetkili atık beyan portalına, gün sonunda toplanan plastik, cam, kağıt ve metal miktarlarını kilogram/hacim cinsinden otomatik raporlayabilecek REST API servis katmanı mevcuttur.
- **OGC / CBS Katman Servisleri:** Konteynerlerin anlık doluluk oranları, belediyelerin kullandığı Coğrafi Bilgi Sistemlerine (ArcGIS, QGIS, Netcad vb.) **GeoJSON** veya **WFS (Web Feature Service)** formatında gerçek zamanlı veri beslemesi (Data Feed) sağlayabilir.

---

## 5. KURULUM VE ÇALIŞTIRMA REHBERİ (Installation Guide)

Sistemi bağımsız bir geliştirme ortamında veya Raspberry Pi 5 üzerinde kurup çalıştırmak için aşağıdaki adımları izleyin.

### A. Donanım Servisi ve AI Modeli Kurulumu
1. **Depoyu klonlayın:**
   ```bash
   git clone https://github.com/your-org/Rebin_Screen.git
   cd Rebin_Screen
   ```

2. **Python Sanal Ortamını Hazırlayın:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install --upgrade pip
   pip install -r rebin_tracker/requirements.txt
   pip install rich opencv-python numpy
   ```

3. **Hailo-8 AI Modelini Hazırlayın:**
   - Proje kök dizininde bulunan `best_rebin.hef` model dosyasının varlığını doğrulayın:
     ```bash
     ls -la best_rebin.hef
     ```
   - Model otomatik olarak `best_rebin.hef` konumundan okunacaktır.

4. **Dedektörü Manuel Başlatın:**
   ```bash
   cd REBIN
   python3 headless_hailo.py
   # veya GUI önizleme ile çalıştırmak için:
   python3 gui_hailo.py
   ```

---

### B. Dokunmatik Kiosk ve Web Arayüzünün Başlatılması
1. **Kiosk HTTP & SSE Sunucusunu Başlatın:**
   ```bash
   cd Ekran
   python3 server.py
   ```
   *Sunucu `http://localhost:8080` adresinde hizmet vermeye başlar.*

2. **Kiosk Modunda Tarayıcıyı Başlatma:**
   ```bash
   bash start_kiosk.sh
   ```
   *Veya tam sunum modunda (Yapay zekâ dedektörü + Kiosk arayüzü tek tuşla):*
   ```bash
   bash REBIN/start_presentation.sh
   ```

---

### C. Arka Plan Sistem Servisleri (systemd)
Sistemin elektrik kesintisi veya cihaz yeniden başlatmalarında otomatik ayağa kalkması için `systemd` servisleri tanımlanmıştır:

1. **Görüntü Senkronizasyon Servisi (`rebin-tracker.service`):**
   ```bash
   sudo cp rebin_tracker/rebin-tracker.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable rebin-tracker.service
   sudo systemctl start rebin-tracker.service
   ```

2. **Yapay Zekâ Dedektör Servisi (`rebin_detector.service`):**
   ```bash
   sudo cp REBIN/rebin_detector.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable rebin_detector.service
   sudo systemctl start rebin_detector.service
   ```

---

### D. Mobil Uygulama Kurulumu
1. **Flutter Ortamını Hazırlayın:**
   ```bash
   cd Ekran
   flutter pub get
   ```
2. **Uygulamayı Çalıştırın:**
   ```bash
   flutter run -d chrome     # Web önizleme için
   flutter run -d android    # Saha tableti veya Android telefon için
   ```

---

## 6. KÜTÜPHANELER VE LİSANSLAR (Dependencies & Licensing)

Projede kullanılan temel yazılım bileşenleri ve açık kaynak lisansları:

| Katman | Kütüphane / Teknoloji | Lisans | Kullanım Amacı |
|:---|:---|:---:|:---|
| **Python / Donanım** | `hailo_platform` (HailoRT) | Ticari/Ücretsiz | Hailo-8 13 TOPS NPU derin öğrenme çıkarım motoru |
| | `opencv-python` | Apache 2.0 | Görüntü ön işleme, ROI kırpma ve arka plan hareketi çıkarma |
| | `watchdog` | Apache 2.0 | Kamera fotoğraf klasörü anlık dosya izleme servisi |
| | `supabase` / `supabase-py` | MIT | Supabase Storage & PostgreSQL REST API haberleşmesi |
| | `numpy` | BSD-3-Clause | Matris, tensör manipülasyonu ve normalizasyon |
| | `rich` | MIT | Headless terminal modu canlı gösterge tablosu |
| **Kiosk / Web** | `Vanilla JavaScript / HTML5` | MIT | Ultra düşük kaynak tüketimli 60 FPS kiosk kullanıcı arayüzü |
| | `Leaflet` / `react-leaflet` | BSD-2-Clause | İnteraktif harita, depo ve geri dönüşüm tesisi konumlandırma |
| | `Google Fonts (Outfit)` | OFL | Modern ve okunaklı tipografi |
| **Mobil (Flutter)** | `flutter_riverpod` | MIT | Reaktif state management mimarisi |
| | `supabase_flutter` | MIT | Gerçek zamanlı veritabanı dinleme ve senkronizasyon |
| | `percent_indicator` | BSD-2-Clause | Atık haznesi doluluk barları ve dairesel göstergeler |
| | `go_router` | BSD-3-Clause | Sayfalar arası bildirim ve rota yönlendirmesi |

**Lisans:**  
Bu proje [MIT Lisansı](https://opensource.org/licenses/MIT) altında lisanslanmıştır. Açık kaynak standartlarına uygun olup ticari ve akademik kullanım için uygundur.

---

## 7. DEMO VİDEOSU VE TEKNİK DOKÜMAN LİNKLERİ

* 🎥 **Sistem Canlı Çalışma & Saha Demo Videosu:** [YouTube Demo Linki](https://youtube.com)
* 📦 **Çalıştırılabilir Mobil APK / Dağıtım Paketi:** [Releases Sayfası](https://github.com)
* 📑 **Proje Teknik Raporu & Donanım Şematiği:** [Proje Dokümantasyonu (PDF)](https://drive.google.com)

---
*© 2026 REBIN Smart Waste Solutions. T.C. Sıfır Atık Standartlarıyla Uyumlu Olarak Geliştirilmiştir.*

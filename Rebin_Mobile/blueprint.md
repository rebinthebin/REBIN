# REBIN Projesi Geliştirme Notları

## Genel Bakış

Bu doküman, "REBIN" adlı Flutter tabanlı mobil uygulamanın geliştirme sürecini, mevcut özelliklerini ve gelecek planlarını özetlemektedir. Uygulama, **çevrimdışı öncelikli (offline-first)** bir yardımcı olarak tasarlanmıştır ve kullanıcıların bir hesap oluşturmasına gerek kalmadan, ekledikleri geri dönüşüm kutularını yönetmelerine ve geri dönüşüm süreçlerine aktif olarak katılmalarına olanak tanır.

## Mevcut Özellikler

- **Gerçek Zamanlı Veri Yönetimi:** Firestore veritabanı ile entegrasyon, geri dönüşüm kutularının gerçek zamanlı olarak eklenmesi, güncellenmesi ve silinmesi.
- **Kullanıcı Kimlik Doğrulama:** Arka planda çalışan, kullanıcıya yansıtılmayan Firebase Anonymous Authentication ile güvenli ve anonim veri yönetimi.
- **Dinamik Harita Görünümü:** `flutter_map` ve OpenStreetMap entegrasyonu ile kullanıcıların geri dönüşüm kutularını harita üzerinde görselleştirmesi.
- **Kamera ile Atık Tanıma (Simülasyon):** `camera` paketi ile atık tarama simülasyonu.
- **Kullanıcı Dostu Arayüz:** `go_router` ile modern navigasyon.
- **Yeni Kutu Ekleme:** Harita üzerinden konum seçerek yeni geri dönüşüm kutusu ekleme.
- **Kutu Detayları ve Silme:** Her kutu için ayrı bir detay sayfası ve silme işlevi.

## Uygulanan Adımlar

1.  **Proje Kurulumu ve Bağımlılıkların Eklenmesi.**
2.  **Firebase Entegrasyonu (Anonim).**
3.  **Ana Ekranlar ve Navigasyon Kurulumu.**
4.  **Veri Modelleri ve Servislerinin Oluşturulması.**
5.  **Gerçek Zamanlı Veri Bağlantısının Kurulması.**
6.  **Yeni Kutu Ekleme İşlevinin Tamamlanması.**
7.  **Kutu Detayları ve Silme İşlevinin Tamamlanması.**
8.  **Test ve Dağıtım:** Hatalar ayıklandı ve uygulama web sunucusunda başarıyla çalıştırıldı.

## Son Yapılan Değişiklik: Navigasyonun Yeniden Yapılandırılması (Strateji Değişikliği)

- **Amaç:** Uygulamanın hesap-bağımsız ve çevrimdışı odaklı vizyonunu daha iyi yansıtmak için alt navigasyon barı yeniden düzenlendi.
- **Değişiklikler:**
    - **"Profil" sekmesi kaldırıldı.**
    - **Yeni "Kutularım" Sekmesi:** Navigasyonun en sağına eklendi. Sadece kullanıcı tarafından eklenen kutuların bir listesini gösterir.
    - **Yeni "Aktivite" Sekmesi:** Ortadaki butonun sağına konumlandırıldı. "Görevler", "Bilgi Kartları" ve "Oyunlar" gibi etkileşimli özellikler için bir merkez görevi görür.

## Gelecek Planları ve Potansiyel Geliştirmeler

- **İstatistikler Sayfası:** "Kutularım" sayfasından erişilebilen, kullanıcının geri dönüşüm performansını gösteren bir sayfa.
- **Görevler ve Başarılar:** "Aktivite" merkezinden erişilen, oyunlaştırma öğeleri içeren bir bölüm.
- **Bilgi Kartları:** Geri dönüşümle ilgili eğitici içerikler.
- **Oyunlaştırma:** Geri dönüşüm sürecini daha eğlenceli hale getirecek mini oyunlar.
- **Gelişmiş Atık Tanıma:** Gerçek bir makine öğrenmesi modeli ile atık tanıma özelliğini geliştirmek.

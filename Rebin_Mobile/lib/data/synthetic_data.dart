import 'package:latlong2/latlong.dart';
import '../models/bin_model.dart';

class SyntheticData {
  // Kullanıcının sahte (sentetik) konumu
  static const LatLng userLocation = LatLng(40.994000, 28.700000);

  // pbin_0001 — Özel kutu (yeşil ikon, kullanıcının kendi kutusu)
  static final RebinBin privateBin = RebinBin(
    binId: 'pbin_0001',
    name: 'İGÜ - REBİN',
    isActive: true,
    status: 'active',
    type: 'private',
    plastic: 0.5,
    paper: 0.4,
    glass: 0.3,
    metal: 0.2,
    latitude: 40.993273,
    longitude: 28.699228,
    lastUpdate: DateTime(2026, 5, 2, 0, 0, 0),
    lastEmptying: DateTime(2026, 5, 1, 0, 0, 0),
  );

  // Eski uyumluluk — rebinStation artık privateBin'e yönlendirir
  static RebinBin get rebinStation => privateBin;

  // Kutularım listesi (sadece private kutular)
  static final List<RebinBin> myBins = [
    privateBin,
  ];

  // Tüm kutular (harita için)
  static final List<RebinBin> allBins = [
    privateBin,
  ];
}

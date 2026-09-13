class RebinBin {
  final String binId;       // Benzersiz kutu kimliği (ör: "pbin_0001")
  final String name;        // Kutu adı
  final bool isActive;      // Aktif/deaktif durumu
  final String status;      // Kutu durumu: 'active', 'out_of_order'
  final String type;        // "private" veya "public"
  final double plastic;     // Plastik doluluk oranı (0.0-1.0)
  final double paper;       // Kağıt doluluk oranı (0.0-1.0)
  final double glass;       // Cam doluluk oranı (0.0-1.0)
  final double metal;       // Metal doluluk oranı (0.0-1.0)
  final double general;     // Genel doluluk oranı (hesaplanan)
  final double latitude;    // Enlem
  final double longitude;   // Boylam
  final DateTime lastUpdate;    // Son güncelleme zamanı
  final DateTime lastEmptying;  // Son boşaltım zamanı
  final String? qrToken;    // QR Doğrulama token'ı

  RebinBin({
    required this.binId,
    required this.name,
    this.isActive = true,
    this.status = 'active',
    required this.type,
    this.plastic = 0.0,
    this.paper = 0.0,
    this.glass = 0.0,
    this.metal = 0.0,
    double? general,
    required this.latitude,
    required this.longitude,
    DateTime? lastUpdate,
    DateTime? lastEmptying,
    this.qrToken,
  })  : general = general ?? _calculateGeneral(plastic, paper, glass, metal),
        lastUpdate = lastUpdate ?? DateTime.now(),
        lastEmptying = lastEmptying ?? DateTime.now();

  // --- Genel doluluk hesaplama ---
  static double _calculateGeneral(
      double plastic, double paper, double glass, double metal) {
    int count = 0;
    double total = 0.0;
    if (plastic > 0 || true) { count++; total += plastic; }
    if (paper > 0 || true) { count++; total += paper; }
    if (glass > 0 || true) { count++; total += glass; }
    if (metal > 0 || true) { count++; total += metal; }
    return count > 0 ? total / count : 0.0;
  }

  // --- Kutu durum kontrolleri ---
  bool get isOutOfOrder => status.toLowerCase() == 'out_of_order';
  bool get isStatusActive => status.toLowerCase() == 'active';

  // --- Kutu türü kontrolleri ---
  bool get isPrivate => type == 'private';
  bool get isPublic => type == 'public';

  // --- Doluluk map'i (eski uyumluluk) ---
  Map<String, double> get wasteLevels => {
        'plastic': plastic,
        'paper': paper,
        'glass': glass,
        'metal': metal,
      };

  // --- Zaman farkı formatlaması ---
  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dakika önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} gün önce';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months ay önce';
    } else {
      final years = (diff.inDays / 365).floor();
      return '$years yıl önce';
    }
  }

  String get lastUpdateAgo => timeAgo(lastUpdate);
  String get lastEmptyingAgo => timeAgo(lastEmptying);

  // --- SQLite'dan okuma ---
  factory RebinBin.fromSQLite(Map<String, dynamic> map) {
    return RebinBin(
      binId: map['bin_id'] as String,
      name: map['name'] as String,
      isActive: (map['is_active'] as int) == 1,
      status: map['status'] as String? ?? 'active',
      type: map['type'] as String,
      plastic: (map['plastic'] as num).toDouble(),
      paper: (map['paper'] as num).toDouble(),
      glass: (map['glass'] as num).toDouble(),
      metal: (map['metal'] as num).toDouble(),
      general: (map['general'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      lastUpdate: DateTime.parse(map['last_update'] as String),
      lastEmptying: DateTime.parse(map['last_emptying'] as String),
      qrToken: map['qr_token'] as String?,
    );
  }

  // --- SQLite'a yazma ---
  Map<String, dynamic> toSQLiteMap() {
    return {
      'bin_id': binId,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'status': status,
      'type': type,
      'plastic': plastic,
      'paper': paper,
      'glass': glass,
      'metal': metal,
      'general': general,
      'latitude': latitude,
      'longitude': longitude,
      'last_update': lastUpdate.toIso8601String(),
      'last_emptying': lastEmptying.toIso8601String(),
      'qr_token': qrToken,
    };
  }

  // --- Supabase'den okuma (PostgreSQL) ---
  factory RebinBin.fromSupabase(Map<String, dynamic> map) {
    return RebinBin(
      binId: map['bin_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? true,
      status: map['status'] as String? ?? 'active',
      type: map['type'] as String? ?? 'public',
      plastic: (map['occupancy_plastic'] as num?)?.toDouble() ?? 0.0,
      paper: (map['occupancy_paper'] as num?)?.toDouble() ?? 0.0,
      glass: (map['occupancy_glass'] as num?)?.toDouble() ?? 0.0,
      metal: (map['occupancy_metal'] as num?)?.toDouble() ?? 0.0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      lastUpdate: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : DateTime.now(),
      lastEmptying: map['last_emptying'] != null
          ? DateTime.parse(map['last_emptying'] as String)
          : DateTime.now(),
      qrToken: map['qr_token'] as String?,
    );
  }

  // --- Supabase'e yazma (PostgreSQL) ---
  Map<String, dynamic> toSupabase() {
    return {
      'bin_id': binId,
      'name': name,
      'is_active': isActive,
      'status': status,
      'type': type,
      'occupancy_plastic': plastic,
      'occupancy_paper': paper,
      'occupancy_glass': glass,
      'occupancy_metal': metal,
      'latitude': latitude,
      'longitude': longitude,
      'last_updated': lastUpdate.toIso8601String(),
      'last_emptying': lastEmptying.toIso8601String(),
      if (qrToken != null) 'qr_token': qrToken,
    };
  }

  // --- CopyWith ---
  RebinBin copyWith({
    String? binId,
    String? name,
    bool? isActive,
    String? status,
    String? type,
    double? plastic,
    double? paper,
    double? glass,
    double? metal,
    double? general,
    double? latitude,
    double? longitude,
    DateTime? lastUpdate,
    DateTime? lastEmptying,
    String? qrToken,
  }) {
    return RebinBin(
      binId: binId ?? this.binId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      type: type ?? this.type,
      plastic: plastic ?? this.plastic,
      paper: paper ?? this.paper,
      glass: glass ?? this.glass,
      metal: metal ?? this.metal,
      general: general,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      lastEmptying: lastEmptying ?? this.lastEmptying,
      qrToken: qrToken ?? this.qrToken,
    );
  }
}

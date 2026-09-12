class RebinBin {
  final String binId;
  final String name;
  final bool isPrivate;
  final bool isActive;
  final double general;
  final double plastic;
  final double paper;
  final double glass;
  final double metal;
  final DateTime lastUpdate;
  final String lastUpdateAgo;
  final DateTime lastEmptying;
  final String lastEmptyingAgo;
  final double latitude;
  final double longitude;
  final Map<String, double> wasteLevels;

  const RebinBin({
    required this.binId,
    required this.name,
    this.isPrivate = true,
    this.isActive = true,
    this.general = 0.0,
    this.plastic = 0.0,
    this.paper = 0.0,
    this.glass = 0.0,
    this.metal = 0.0,
    required this.lastUpdate,
    this.lastUpdateAgo = 'Az önce',
    required this.lastEmptying,
    this.lastEmptyingAgo = '1 gün önce',
    this.latitude = 41.0082,
    this.longitude = 28.9784,
    this.wasteLevels = const {},
  });

  RebinBin copyWith({
    String? binId,
    String? name,
    bool? isPrivate,
    bool? isActive,
    double? general,
    double? plastic,
    double? paper,
    double? glass,
    double? metal,
    DateTime? lastUpdate,
    String? lastUpdateAgo,
    DateTime? lastEmptying,
    String? lastEmptyingAgo,
    double? latitude,
    double? longitude,
    Map<String, double>? wasteLevels,
  }) {
    return RebinBin(
      binId: binId ?? this.binId,
      name: name ?? this.name,
      isPrivate: isPrivate ?? this.isPrivate,
      isActive: isActive ?? this.isActive,
      general: general ?? this.general,
      plastic: plastic ?? this.plastic,
      paper: paper ?? this.paper,
      glass: glass ?? this.glass,
      metal: metal ?? this.metal,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      lastUpdateAgo: lastUpdateAgo ?? this.lastUpdateAgo,
      lastEmptying: lastEmptying ?? this.lastEmptying,
      lastEmptyingAgo: lastEmptyingAgo ?? this.lastEmptyingAgo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      wasteLevels: wasteLevels ?? this.wasteLevels,
    );
  }
}

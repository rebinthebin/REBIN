import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

final statisticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = UserStaticsDatabase.instance;
  await db.injectSyntheticDataIfNeeded(); 

  final scans = await db.getWasteScans();
  final counts = await db.getWasteCountByType();

  // EEA Standartlarına Göre Tahmini Tasarruf Değerleri (1 birim atık için)
  // Plastik: 1.5kg CO2, 2.0L Su
  // Kağıt: 0.8kg CO2, 5.0L Su
  // Cam: 0.5kg CO2, 0.5L Su
  // Metal: 2.0kg CO2, 1.0L Su
  
  double totalCo2 = 0.0;
  double totalWater = 0.0;
  
  counts.forEach((label, count) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('plastik')) {
      totalCo2 += count * 1.5;
      totalWater += count * 2.0;
    } else if (lowerLabel.contains('kağıt') || lowerLabel.contains('kagit')) {
      totalCo2 += count * 0.8;
      totalWater += count * 5.0;
    } else if (lowerLabel.contains('cam')) {
      totalCo2 += count * 0.5;
      totalWater += count * 0.5;
    } else if (lowerLabel.contains('metal')) {
      totalCo2 += count * 2.0;
      totalWater += count * 1.0;
    }
  });

  final generalStats = await db.getGeneralStatics();

  return {
    'scans': scans,
    'counts': counts,
    'totalScans': scans.length,
    'co2': totalCo2,
    'water': totalWater,
    'generalStats': generalStats,
  };
});

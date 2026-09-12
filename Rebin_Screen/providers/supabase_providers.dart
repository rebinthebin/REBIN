import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bin_model.dart';

final privateBinsProvider = FutureProvider<List<RebinBin>>((ref) async {
  return <RebinBin>[];
});

final allBinsProvider = FutureProvider<List<RebinBin>>((ref) async {
  return <RebinBin>[];
});

final binByIdProvider = FutureProvider.family<RebinBin, String>((ref, id) async {
  return RebinBin(
    binId: id,
    name: 'REBIN Kutu',
    lastUpdate: DateTime.now(),
    lastEmptying: DateTime.now(),
  );
});

final binImagesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  return <Map<String, dynamic>>[];
});

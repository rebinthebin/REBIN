import '../models/bin_model.dart';

class BinDatabaseService {
  static final BinDatabaseService instance = BinDatabaseService._init();

  BinDatabaseService._init();

  Future<void> updateBin(RebinBin bin) async {}
  Future<void> deleteBin(String binId) async {}
}

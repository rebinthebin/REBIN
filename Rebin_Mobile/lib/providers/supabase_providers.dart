import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/bin_database_service.dart';
import '../models/bin_model.dart';

// 0. Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

// 1. SupabaseService instance'ını sağlayan provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

// 2. BinDatabaseService instance'ını sağlayan provider
final binDatabaseServiceProvider = Provider<BinDatabaseService>((ref) {
  return BinDatabaseService.instance;
});

// 3. Sadece kullanıcının kendi kutularını (Private) çeken provider
final privateBinsProvider = FutureProvider.autoDispose<List<RebinBin>>((ref) async {
  final dbService = ref.read(binDatabaseServiceProvider);
  final supabaseService = ref.read(supabaseServiceProvider);
  
  // 1. Önce lokalden (SQLite) kutuları al
  final localBins = await dbService.getPrivateBins();
  
  // 2. Arka planda Supabase'den güncel verileri çek
  try {
    List<RebinBin> updatedBins = [];
    for (var bin in localBins) {
      final freshBin = await supabaseService.getBinById(bin.binId);
      if (freshBin != null) {
        // SQLite'ı güncelle
        // Burada kullanıcının yerel ismini (name) ve qrToken'ını koruyoruz
        final binWithLocalData = freshBin.copyWith(
          name: bin.name, 
          qrToken: bin.qrToken,
        );
        await dbService.insertOrUpdateBin(binWithLocalData);
        updatedBins.add(binWithLocalData);
      } else {
        updatedBins.add(bin);
      }
    }
    return updatedBins;
  } catch (e) {
    print("[Provider] Supabase senkronizasyon hatası: $e");
    return localBins;
  }
});

// 4. Tüm kutuları çeken provider (Lokal SQLite source of truth)
final allBinsProvider = FutureProvider.autoDispose<List<RebinBin>>((ref) async {
  final dbService = ref.read(binDatabaseServiceProvider);
  return await dbService.getAllBins();
});

// 5. Belirli bir kutuyu ID ile çeken FutureProvider.family
final binByIdProvider = FutureProvider.autoDispose.family<RebinBin?, String>((ref, binId) async {
  final dbService = ref.read(binDatabaseServiceProvider);
  final localBin = await dbService.getBinById(binId);
  
  final supabaseService = ref.read(supabaseServiceProvider);
  
  try {
    final freshBin = await supabaseService.getBinById(binId);
    
    if (freshBin != null) {
      // Senkronizasyon: Supabase'den gelen veriyi SQLite'a kaydet (name hariç)
      // ÖNEMLİ: Eğer kutu yerelde (SQLite) yoksa, burası onu tekrar eklemesin.
      // Kutu ekleme işlemi sadece QR Scan veya Manual Add üzerinden yapılmalı.
      if (localBin != null) {
        final binToSave = freshBin.copyWith(
          name: localBin.name,
          qrToken: localBin.qrToken,
        );
        await dbService.insertOrUpdateBin(binToSave);
        return binToSave;
      }
    }
    
    return localBin;
  } catch (e) {
    print("[Provider] binByIdProvider hatası: $e");
    return localBin;
  }
});

// 6. Belirli bir kutunun atık görüntülerini çeken provider
final binImagesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, binId) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.getBinImages(binId);
});

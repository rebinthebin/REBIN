import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bin_model.dart';

/// Supabase üzerinden rebins ve bin_images tablolarına erişim sağlayan servis.
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // --- rebins Tablosu ---

  /// Tüm kutuları gerçek zamanlı olarak stream et
  Stream<List<RebinBin>> getBinsStream() {
    return _client
        .from('rebins')
        .stream(primaryKey: ['bin_id'])
        .map((data) => data.map((map) => RebinBin.fromSupabase(map)).toList());
  }

  /// Sadece Public (Topluma Açık) olan kutuları getir
  Future<List<RebinBin>> getPublicBins() async {
    try {
      final data = await _client
          .from('rebins')
          .select()
          .eq('type', 'public');
      return (data as List).map((map) => RebinBin.fromSupabase(map)).toList();
    } catch (e) {
      print("[SupabaseService] Public bins fetch hatası: $e");
      return [];
    }
  }

  /// Bin ID ile kutu getir
  Future<RebinBin?> getBinById(String binId) async {
    try {
      final data = await _client
          .from('rebins')
          .select()
          .eq('bin_id', binId)
          .maybeSingle();
      if (data != null) {
        return RebinBin.fromSupabase(data);
      }
      return null;
    } catch (e) {
      print("[SupabaseService] getBinById hatası: $e");
      return null;
    }
  }

  /// QR doğrulama için kutu getir (qr_token ile)
  Future<RebinBin?> getBinByQrToken(String rawQrToken) async {
    try {
      final data = await _client
          .from('rebins')
          .select()
          .eq('qr_token', rawQrToken)
          .maybeSingle();
      if (data != null) {
        return RebinBin.fromSupabase(data);
      } else {
        print("[SupabaseService] Kutu bulunamadı, qr_token: $rawQrToken");
        return null;
      }
    } catch (e) {
      print("[SupabaseService] getBinByQrToken hatası: $e");
      rethrow;
    }
  }

  /// Yeni bir geri dönüşüm kutusu ekle
  Future<void> addBin(RebinBin bin) async {
    try {
      await _client.from('rebins').upsert(bin.toSupabase());
    } catch (e) {
      print("[SupabaseService] Kutu eklenemedi: $e");
      rethrow;
    }
  }

  /// Bir kutunun atık seviyelerini güncelle
  Future<void> updateWasteLevel(String binId, String wasteType, double newLevel) async {
    try {
      // Supabase'de sütun adı: occupancy_plastic, occupancy_glass vb.
      final columnName = 'occupancy_$wasteType';
      await _client.from('rebins').update({
        columnName: newLevel,
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('bin_id', binId);
    } catch (e) {
      print("[SupabaseService] Atık seviyesi güncellenemedi: $e");
      rethrow;
    }
  }

  /// Bir geri dönüşüm kutusunu sil
  Future<void> deleteBin(String binId) async {
    try {
      await _client.from('rebins').delete().eq('bin_id', binId);
    } catch (e) {
      print("[SupabaseService] Kutu silinemedi: $e");
      rethrow;
    }
  }

  // --- bin_images Tablosu ---

  /// Belirli bir kutunun atık görüntülerini getir (en yeni en üstte)
  Future<List<Map<String, dynamic>>> getBinImages(String binId) async {
    try {
      final data = await _client
          .from('bin_images')
          .select()
          .eq('bin_id', binId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("[SupabaseService] getBinImages hatası: $e");
      return [];
    }
  }
}

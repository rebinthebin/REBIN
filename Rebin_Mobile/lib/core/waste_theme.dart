import 'package:flutter/material.dart';

/// T.C. Çevre, Şehircilik ve İklim Değişikliği Bakanlığı
/// Sıfır Atık Yönetmeliği Resmi Piktogram ve Renk Standartları
class WasteTheme {
  // --- 1. KAĞIT ATIKLAR (Sarı / Turuncu) ---
  static const Color paperColor = Color(0xFFFBC02D);
  static const Color paperSoftBg = Color(0xFFFFFDE7);
  static const Color paperDarkColor = Color(0xFFF57F17);
  static const IconData paperIcon = Icons.newspaper;
  static const IconData paperBoxIcon = Icons.inventory_2_outlined;

  // --- 2. PLASTİK ATIKLAR (Mavi) ---
  static const Color plasticColor = Color(0xFF1565C0);
  static const Color plasticSoftBg = Color(0xFFEBF3FA);
  static const Color plasticDarkColor = Color(0xFF0D47A1);
  static const IconData plasticIcon = Icons.local_drink_outlined;
  static const IconData plasticBottleIcon = Icons.cleaning_services_outlined;

  // --- 3. CAM ATIKLAR (Canlı Yeşil) ---
  static const Color glassColor = Color(0xFF388E3C);
  static const Color glassSoftBg = Color(0xFFE8F5E9);
  static const Color glassDarkColor = Color(0xFF2E7D32);
  static const IconData glassIcon = Icons.wine_bar_outlined;
  static const IconData glassJarIcon = Icons.kitchen_outlined;

  // --- 4. METAL ATIKLAR (Kırmızı / Pembe) ---
  static const Color metalColor = Color(0xFFE53935);
  static const Color metalSoftBg = Color(0xFFFFEBEE);
  static const Color metalDarkColor = Color(0xFFC62828);
  static const IconData metalIcon = Icons.takeout_dining_outlined;
  static const IconData metalCanIcon = Icons.view_in_ar_outlined;

  // --- ÇÖP / GERİ DÖNÜŞMEYEN ATIKLAR (Koyu Gri) ---
  static const Color trashColor = Color(0xFF616161);
  static const Color trashSoftBg = Color(0xFFEEEEEE);

  // --- ARIZA / OUT OF ORDER DURUM RENKLERİ ---
  static const Color outOfOrderBorderColor = Color(0xFFD97706); // Koyu Sarı / Amber 600
  static const Color outOfOrderBgColor = Color(0xFFFEF3C7);     // Amber 100 Soft
  static const Color outOfOrderTextColor = Color(0xFFB45309);  // Amber 700

  /// Malzeme adına göre ana rengi döndürür
  static Color getColor(String material) {
    final lower = material.toLowerCase();
    if (lower.contains('kağıt') || lower.contains('kagit') || lower.contains('paper')) {
      return paperColor;
    } else if (lower.contains('plastik') || lower.contains('plastic')) {
      return plasticColor;
    } else if (lower.contains('cam') || lower.contains('glass')) {
      return glassColor;
    } else if (lower.contains('metal')) {
      return metalColor;
    } else if (lower.contains('çöp') || lower.contains('cop') || lower.contains('trash')) {
      return trashColor;
    }
    return Colors.grey;
  }

  /// Malzeme adına göre açık/soft arka plan rengini döndürür
  static Color getSoftBg(String material) {
    final lower = material.toLowerCase();
    if (lower.contains('kağıt') || lower.contains('kagit') || lower.contains('paper')) {
      return paperSoftBg;
    } else if (lower.contains('plastik') || lower.contains('plastic')) {
      return plasticSoftBg;
    } else if (lower.contains('cam') || lower.contains('glass')) {
      return glassSoftBg;
    } else if (lower.contains('metal')) {
      return metalSoftBg;
    } else if (lower.contains('çöp') || lower.contains('cop') || lower.contains('trash')) {
      return trashSoftBg;
    }
    return Colors.grey.shade100;
  }

  /// Malzeme adına göre ikon döndürür
  static IconData getIcon(String material) {
    final lower = material.toLowerCase();
    if (lower.contains('kağıt') || lower.contains('kagit') || lower.contains('paper')) {
      return paperIcon;
    } else if (lower.contains('plastik') || lower.contains('plastic')) {
      return plasticIcon;
    } else if (lower.contains('cam') || lower.contains('glass')) {
      return glassIcon;
    } else if (lower.contains('metal')) {
      return metalIcon;
    }
    return Icons.recycling;
  }
}

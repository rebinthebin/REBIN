import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bin_model.dart';
import '../providers/supabase_providers.dart';
import '../services/bin_database_service.dart';
import '../providers/weekly_task_provider.dart';
import 'package:flutter/scheduler.dart';

class RebinDetailScreen extends ConsumerWidget {
  final String binId;

  const RebinDetailScreen({super.key, required this.binId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binAsync = ref.watch(binByIdProvider(binId));

    // İlk yükleme: loading göster (henüz veri yoksa)
    if (binAsync.isLoading && !binAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Hata: veri yoksa hata göster
    if (binAsync.hasError && !binAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Hata', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(child: Text('Veri yüklenirken hata oluştu: ${binAsync.error}')),
      );
    }

    final bin = binAsync.valueOrNull;
    if (bin == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Kutu Bulunamadı', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Bu kutu bulunamadı.',
                style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return _buildDetailView(context, ref, bin);
  }

  Widget _buildDetailView(BuildContext context, WidgetRef ref, RebinBin bin) {
    final bool isPrivate = bin.isPrivate;
    final Color themeColor = isPrivate ? Colors.green : Colors.blue;

    // Eğer kutu topluma açıksa (public), haftalık görevi bir kez artır
    if (!isPrivate) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ref.read(weeklyTaskProvider.notifier).incrementTask('view_public');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(bin.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (isPrivate)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showEditDialog(context, ref, bin);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Provider'ları invalidate ederek veritabanından güncel verileri çek
          ref.invalidate(binByIdProvider(binId));
          ref.invalidate(privateBinsProvider);
          ref.invalidate(binImagesProvider(binId));
          // Yeni verinin yüklenmesini bekle
          await ref.read(binByIdProvider(binId).future);
        },
        color: themeColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Status & Type Header ---
              Row(
                children: [
                  // Aktif/Deaktif Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: bin.isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: bin.isActive ? Colors.green.shade300 : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bin.isActive ? Icons.check_circle : Icons.cancel,
                          color: bin.isActive ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          bin.isActive ? 'Aktif' : 'Deaktif',
                          style: GoogleFonts.outfit(
                            color: bin.isActive ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tür Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrivate ? Icons.lock : Icons.public,
                          color: themeColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPrivate ? 'Özel' : 'Topluma Açık',
                          style: GoogleFonts.outfit(
                            color: themeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Kutu ID
              Text(
                'ID: ${bin.binId}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 28),

              // --- Genel Doluluk ---
              Center(
                child: Column(
                  children: [
                    Text(
                      'Genel Doluluk',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircularPercentIndicator(
                      radius: 70.0,
                      lineWidth: 12.0,
                      percent: bin.general.clamp(0.0, 1.0),
                      center: Text(
                        '%${(bin.general * 100).toInt()}',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      progressColor: themeColor,
                      backgroundColor: themeColor.withValues(alpha: 0.15),
                      circularStrokeCap: CircularStrokeCap.round,
                      animation: true,
                      animationDuration: 1200,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              
              // --- Bölme Doluluk Oranları ---
              Text(
                'Bölme Doluluk Oranları',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildWasteBar('Plastik', bin.plastic, Colors.blue),
              const SizedBox(height: 16),
              _buildWasteBar('Kağıt', bin.paper, Colors.amber),
              const SizedBox(height: 16),
              _buildWasteBar('Cam', bin.glass, Colors.green),
              const SizedBox(height: 16),
              _buildWasteBar('Metal', bin.metal, Colors.red),
              
              const SizedBox(height: 32),

              // --- Zaman Bilgileri ---
              Text(
                'Takip Bilgileri',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Son Güncelleme
              _buildInfoCard(
                icon: Icons.update,
                iconColor: Colors.orange,
                title: 'Son Güncelleme',
                subtitle: _formatDateTime(bin.lastUpdate),
                trailing: bin.lastUpdateAgo,
              ),
              const SizedBox(height: 12),
              // Son Boşaltım
              _buildInfoCard(
                icon: Icons.cleaning_services,
                iconColor: Colors.teal,
                title: 'Son Boşaltım',
                subtitle: _formatDateTime(bin.lastEmptying),
                trailing: bin.lastEmptyingAgo,
              ),
              
              const SizedBox(height: 32),

              // --- Konum Bilgisi ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.black87),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konum',
                            style: GoogleFonts.outfit(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${bin.latitude.toStringAsFixed(4)}° N, ${bin.longitude.toStringAsFixed(4)}° E',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Harita Butonu ---
              ElevatedButton.icon(
                onPressed: () {
                  // Harita sayfasına git ve kutu konumunu 'extra' olarak gönder
                  context.go('/map', extra: latlong.LatLng(bin.latitude, bin.longitude));
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Harita üzerinde görüntüle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Atık Görüntüleri Butonu ---
              OutlinedButton.icon(
                onPressed: () {
                  _showWasteImagesModal(context, ref, bin);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Atık Görüntüleri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: themeColor,
                  side: BorderSide(color: themeColor, width: 1.5),
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Hata / Arıza Bildir Butonu ---
              OutlinedButton.icon(
                onPressed: () {
                  _showErrorReportModal(context, bin.binId);
                },
                icon: const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                label: const Text('Hata / Arıza Bildir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 80), // Sistem bileşenleri ile çakışmayı önlemek için ek boşluk
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWasteBar(String label, double level, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '%${(level * 100).toInt()}',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 12.0,
          percent: level.clamp(0.0, 1.0),
          animation: true,
          animationDuration: 1000,
          barRadius: const Radius.circular(6),
          progressColor: color,
          backgroundColor: color.withValues(alpha: 0.1),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // --- Atık Görüntüleri Bottom Sheet ---
  void _showWasteImagesModal(BuildContext context, WidgetRef ref, RebinBin bin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Tutamaç (Handle)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Başlık
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atık Görüntüleri',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            bin.name,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // İçerik (GridView)
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final imagesAsync = ref.watch(binImagesProvider(bin.binId));

                      return imagesAsync.when(
                        data: (images) {
                          if (images.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Henüz atık görüntüsü kaydedilmemiş.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              final item = images[index];
                              final imageUrl = item['image_url'] as String? ?? '';
                              final wasteType = item['waste_type'] as String? ?? 'Bilinmiyor';

                              return GestureDetector(
                                onTap: () => _showImageDetailDialog(context, item),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (imageUrl.isNotEmpty)
                                        Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            );
                                          },
                                        )
                                      else
                                        Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        ),
                                      // Atık türü etiket bandı
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          color: Colors.black54,
                                          child: Text(
                                            wasteType,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Text(
                            'Görüntüler yüklenirken hata oluştu: $error',
                            style: GoogleFonts.outfit(color: Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Görsel Detay Dialogu ---
  void _showImageDetailDialog(BuildContext context, Map<String, dynamic> item) {
    final imageUrl = item['image_url'] as String? ?? '';
    final wasteType = item['waste_type'] as String? ?? 'Bilinmiyor';
    final confidence = (item['confidence'] as num?)?.toDouble();
    final createdAtStr = item['created_at'] as String?;
    DateTime? createdAt;
    if (createdAtStr != null) {
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resim
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              // Detaylar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          wasteType,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (confidence != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              '%${(confidence * 100).toStringAsFixed(1)}',
                              style: GoogleFonts.outfit(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (createdAt != null)
                      Text(
                        _formatDateTime(createdAt),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Kapat',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, RebinBin bin) {
    final TextEditingController nameController = TextEditingController(text: bin.name);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Kutu İsmini Düzenle', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: 'Yeni isim',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Divider(height: 32),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showDeleteConfirmDialog(context, ref, bin);
                },
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                label: Text('Kutuyu Sil', style: GoogleFonts.outfit(color: Colors.redAccent)),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // İptal
              },
              child: Text('İptal', style: GoogleFonts.outfit(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  final updatedBin = bin.copyWith(name: newName);
                  await BinDatabaseService.instance.updateBin(updatedBin);
                  ref.invalidate(binByIdProvider(bin.binId));
                  ref.invalidate(privateBinsProvider);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Kaydet sonrası kapat
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Kaydet', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, RebinBin bin) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Kutuyu Sil', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            '"${bin.name}" kutusunu kalıcı olarak silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz.',
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // İptal
              },
              child: Text('İptal', style: GoogleFonts.outfit(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                // SQLite'dan kalıcı olarak sil (bin_id baz alınarak DELETE query)
                await BinDatabaseService.instance.deleteBin(bin.binId);
                debugPrint("[Delete] Kutu SQLite'dan kalıcı olarak silindi: ${bin.binId}");
                
                // Tüm ilgili provider'ları invalidate et — UI her yerde güncellenir
                ref.invalidate(privateBinsProvider);
                ref.invalidate(allBinsProvider);
                ref.invalidate(binByIdProvider(bin.binId));
                ref.invalidate(binImagesProvider(bin.binId));
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Dialogu kapat
                }
                if (context.mounted) {
                  // Başarı mesajı göster
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${bin.name}" kalıcı olarak silindi.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  context.pop(); // Sayfadan çık
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Kalıcı Olarak Sil', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Hata / Arıza Bildirim Modalı ---
  void _showErrorReportModal(BuildContext context, String currentBinId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Karşılaştığınız sorunu seçiniz',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Seçtiğiniz bildirim teknik ekibimize iletilecektir.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildErrorOptionButton(
                  context: bottomSheetContext,
                  currentBinId: currentBinId,
                  errorKey: 'error_1',
                  label: 'Rebin malzemeyi algılamıyor!',
                ),
                const SizedBox(height: 10),
                _buildErrorOptionButton(
                  context: bottomSheetContext,
                  currentBinId: currentBinId,
                  errorKey: 'error_2',
                  label: 'Rebin malzemeyi sınıflandırmıyor!',
                ),
                const SizedBox(height: 10),
                _buildErrorOptionButton(
                  context: bottomSheetContext,
                  currentBinId: currentBinId,
                  errorKey: 'error_3',
                  label: 'Rebin malzemeyi ayrıştırmıyor',
                ),
                const SizedBox(height: 10),
                _buildErrorOptionButton(
                  context: bottomSheetContext,
                  currentBinId: currentBinId,
                  errorKey: 'error_4',
                  label: 'Diğer nedenler',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorOptionButton({
    required BuildContext context,
    required String currentBinId,
    required String errorKey,
    required String label,
  }) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await _handleReportError(context, currentBinId, errorKey, label);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade300),
              ),
              child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReportError(
    BuildContext context,
    String currentBinId,
    String errorKey,
    String issueLabel,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Kontrol ve Okuma: Seçili bin_id için bin_errors tablosunda satır var mı?
      final response = await supabase
          .from('bin_errors')
          .select()
          .eq('bin_id', currentBinId)
          .maybeSingle();

      final nowIso = DateTime.now().toIso8601String();

      // 2. Ekleme veya Güncelleme Mantığı (Atomic Increment / Upsert)
      if (response == null) {
        // Durum A (Satır Yoksa): Yeni satır ekle (tıklanan 1, diğerleri 0)
        await supabase.from('bin_errors').insert({
          'bin_id': currentBinId,
          'error_1': errorKey == 'error_1' ? 1 : 0,
          'error_2': errorKey == 'error_2' ? 1 : 0,
          'error_3': errorKey == 'error_3' ? 1 : 0,
          'error_4': errorKey == 'error_4' ? 1 : 0,
          'last_reported_at': nowIso,
        });
      } else {
        // Durum B (Satır Varsa): Mevcut satırdaki tıklanan hata türünü 1 artır
        final currentVal = (response[errorKey] as num?)?.toInt() ?? 0;
        await supabase.from('bin_errors').update({
          errorKey: currentVal + 1,
          'last_reported_at': nowIso,
        }).eq('bin_id', currentBinId);
      }

      // 3. Kullanıcı Geri Bildirimi
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sorun bildiriminiz başarıyla iletildi: $issueLabel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bildirim iletilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

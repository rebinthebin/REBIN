import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../providers/supabase_providers.dart';
import '../providers/daily_task_provider.dart';
import '../models/bin_model.dart';

// Widget'ı ConsumerWidget'a dönüştür
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    // Her ekran geçişinde verileri veritabanından yeniden oku
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(privateBinsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final binsAsyncValue = ref.watch(privateBinsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Çıkmak için tekrar basın"),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.black87,
            ),
          );
          return;
        }
        // Eğer 2 saniye içinde tekrar basıldıysa uygulamadan çık
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            "REBIN Mobile! ♻️",
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 120.0,
          ), // Nav bar ile çakışmayı önlemek için alt boşluk
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              binsAsyncValue.when(
                data: (bins) {
                  if (bins.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Henüz bir kutu eklemediniz."),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              context.push('/my-bins');
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              "KUTU EKLE",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Alfabetik sıralama yapıyoruz
                  final sortedBins = List<RebinBin>.from(bins);
                  sortedBins.sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );

                  final latestBin = sortedBins.first;
                  return _buildLatestBinCard(context, latestBin);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('Veri yüklenirken hata oluştu: $err')),
              ),
              const SizedBox(height: 16),
              _buildDailyActivityCard(context, ref),
              const SizedBox(height: 16),
              _buildActionCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestBinCard(BuildContext context, RebinBin bin) {
    // Genel doluluk oranı
    double overallFill = bin.general;
    // Nan ihtimaline karşı kontrol
    if (overallFill.isNaN) overallFill = 0.0;

    // Tüm kartı tıklanabilir yap — herhangi bir yere dokunulduğunda kutu detayına git
    return GestureDetector(
      onTap: () {
        context.push('/rebin-detail', extra: bin.binId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // Oval köşeli
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  // Sol tarafta yuvarlak geri dönüşüm logosu
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.recycling,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // İsim ve "Özel kutu" yazısı
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            bin.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'Özel kutu',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Genel doluluk oranı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Genel Doluluk',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '%${(overallFill * 100).toInt()}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearPercentIndicator(
              lineHeight: 8.0,
              percent: overallFill.clamp(0.0, 1.0),
              animation: true,
              barRadius: const Radius.circular(4),
              progressColor: Colors.green,
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            // 4 bölmeli ızgara (2x2 tam genişlik)
            LayoutBuilder(
              builder: (context, constraints) {
                final double spacing = 12.0;
                final double cardWidth = (constraints.maxWidth - spacing) / 2;
                final double cardHeight =
                    cardWidth * 0.82; // Kare'ye yakın, daha yüksek kutular
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _buildWasteCard(
                        context: context,
                        title: 'Plastik',
                        percent: bin.wasteLevels['plastic'] ?? 0.0,
                        color: Colors.blue.shade700,
                        icon: Icons.local_drink_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _buildWasteCard(
                        context: context,
                        title: 'Kağıt',
                        percent: bin.wasteLevels['paper'] ?? 0.0,
                        color: Colors.amber.shade600,
                        icon: Icons.article_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _buildWasteCard(
                        context: context,
                        title: 'Cam',
                        percent: bin.wasteLevels['glass'] ?? 0.0,
                        color: Colors.green.shade600,
                        icon: Icons.wine_bar_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _buildWasteCard(
                        context: context,
                        title: 'Metal',
                        percent: bin.wasteLevels['metal'] ?? 0.0,
                        color: Colors.red.shade400,
                        icon: Icons.kitchen_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteCard({
    required BuildContext context,
    required String title,
    required double percent,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: CircularPercentIndicator(
                radius: 30.0,
                lineWidth: 6.0,
                percent: percent.clamp(0.0, 1.0),
                center: Icon(icon, size: 26, color: color),
                progressColor: color,
                backgroundColor: color.withValues(alpha: 0.2),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            '%${(percent * 100).toInt()} Dolu',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyActivityCard(BuildContext context, WidgetRef ref) {
    final dailyTaskAsyncValue = ref.watch(dailyTaskProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/tasks');
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: dailyTaskAsyncValue.when(
            data: (dailyTask) {
              final int dailyCurrent = dailyTask.currentCount;
              final int target = dailyTask.target;
              final bool isCompleted = dailyCurrent >= target;
              final double percent = (dailyCurrent / target).clamp(0.0, 1.0);
              final int displayCurrent = min(dailyCurrent, target);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Günlük Aktivite",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (isCompleted)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$target tane ${dailyTask.material} malzeme tarat",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearPercentIndicator(
                          lineHeight: 8.0,
                          percent: percent,
                          animation: true,
                          barRadius: const Radius.circular(4),
                          progressColor: Colors.green,
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "($displayCurrent/$target)",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, stack) => const Text('Görev yüklenemedi.'),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.go('/map'),
        splashColor: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "En Yakın Geri Dönüşüm Noktasını Bul",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

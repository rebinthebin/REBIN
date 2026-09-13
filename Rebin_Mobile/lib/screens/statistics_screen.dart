import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/statistics_provider.dart';
import '../providers/supabase_providers.dart';
import '../models/bin_model.dart';
import '../core/waste_theme.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statisticsProvider);
    final binsAsync = ref.watch(privateBinsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('İstatistikler ve Analiz', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: statsAsync.when(
        data: (stats) {
          final int totalScans = stats['totalScans'];
          final double totalCo2 = stats['co2'];
          final double totalWater = stats['water'];
          final counts = stats['counts'] as Map<String, int>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader('Çevresel Etki Analizi (EEA)'),
                const SizedBox(height: 16),
                _buildImpactCards(totalCo2, totalWater),
                const SizedBox(height: 32),
                
                _buildHeader('Taratılan Malzemeler'),
                const SizedBox(height: 16),
                _buildMaterialsTable(counts, totalScans),
                const SizedBox(height: 32),

                _buildHeader('Kutularım Doluluk Oranları'),
                const SizedBox(height: 16),
                binsAsync.when(
                  data: (bins) {
                    if (bins.isEmpty) {
                      return const Center(child: Text('Henüz kutu eklenmemiş.'));
                    }
                    return _buildBinsChart(bins);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Kutular yüklenemedi: $e'),
                ),
                const SizedBox(height: 32),

                _buildHeader('Tamamlanan Görevler'),
                const SizedBox(height: 16),
                _buildCompletedTasksSection(stats['generalStats'] ?? {}),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildImpactCards(double co2, double water) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'CO2 Azaltımı',
            value: '${co2.toStringAsFixed(1)} kg',
            icon: Icons.cloud_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Su Tasarrufu',
            value: '${water.toStringAsFixed(1)} L',
            icon: Icons.water_drop_outlined,
            color: Colors.cyan,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildMaterialsTable(Map<String, int> counts, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Toplam Tarama', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade700)),
              Text('$total', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 32),
          if (counts.isEmpty)
            const Text('Henüz malzeme taratılmadı.')
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Malzeme Türü', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Adet', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    ),
                  ],
                ),
                ...counts.entries.map((e) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: _getColorForMaterial(e.key), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Text(e.key, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('${e.value}', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedTasksSection(Map<String, int> genStats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildTaskRow('Tamamlanan günlük görevler', genStats['daily_tasks'] ?? 0, Colors.orange),
          const Divider(height: 24),
          _buildTaskRow('Tamamlanan haftalık görevler', genStats['weekly_tasks'] ?? 0, Colors.purple),
          const Divider(height: 24),
          _buildTaskRow('Okunan bilgi kartları', genStats['info_cards'] ?? 0, Colors.teal),
          const Divider(height: 24),
          _buildTaskRow('Oynanan oyun sayısı', genStats['games_played'] ?? 0, Colors.indigo),
        ],
      ),
    );
  }

  Widget _buildTaskRow(String title, int value, Color iconColor) {
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: iconColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(title, style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87)),
        ),
        Text('$value', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor)),
      ],
    );
  }

  Color _getColorForMaterial(String material) {
    return WasteTheme.getColor(material);
  }

  Widget _buildBinsChart(List<RebinBin> bins) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (index >= 0 && index < bins.length) {
                    final name = bins[index].name;
                    // Uzun isimleri kısaltalım
                    final shortName = name.length > 8 ? '${name.substring(0, 6)}..' : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        shortName,
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '%${value.toInt()}',
                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(bins.length, (index) {
            final bin = bins[index];
            final percent = (bin.general * 100).clamp(0.0, 100.0);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: percent,
                  color: Colors.green.shade400,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: Colors.grey.shade100,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/statistics_provider.dart';
import '../providers/daily_task_provider.dart';
import '../providers/weekly_task_provider.dart';
import '../core/waste_theme.dart';
import 'dart:math';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Görevler & Başarılar',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: statsAsync.when(
        data: (stats) {
          final counts = stats['counts'] as Map<String, int>;
          final int paperCount = counts.entries.firstWhere((e) => e.key.toLowerCase().contains('kağıt') || e.key.toLowerCase().contains('kagit'), orElse: () => const MapEntry('', 0)).value;
          final int plasticCount = counts.entries.firstWhere((e) => e.key.toLowerCase().contains('plastik'), orElse: () => const MapEntry('', 0)).value;
          final int glassCount = counts.entries.firstWhere((e) => e.key.toLowerCase().contains('cam'), orElse: () => const MapEntry('', 0)).value;
          final int metalCount = counts.entries.firstWhere((e) => e.key.toLowerCase().contains('metal'), orElse: () => const MapEntry('', 0)).value;
          
          final dailyTaskAsync = ref.watch(dailyTaskProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Günlük Görev",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                dailyTaskAsync.when(
                  data: (task) => _buildDailyActivityCard(context, ref, task, task.currentCount),
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (err, stack) => const Text('Görev yüklenemedi.'),
                ),
                const SizedBox(height: 32),
                Text(
                  "Haftalık Görev",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ref.watch(weeklyTaskProvider).when(
                  data: (tasks) => Column(
                    children: tasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildWeeklyTaskCard(context, task),
                    )).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => const Text('Haftalık görevler yüklenemedi.'),
                ),
                const SizedBox(height: 32),
                Text(
                  "Başarılar",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // 50'lik Başarılar (Sıfır Atık Standart Renkleri)
                _buildAchievementCard(
                  context: context,
                  title: "50 Defa Kağıt Malzeme Tarat",
                  iconData: WasteTheme.paperIcon,
                  target: 50,
                  current: paperCount,
                  color: WasteTheme.paperColor,
                ),
                const SizedBox(height: 16),
                _buildAchievementCard(
                  context: context,
                  title: "50 Defa Plastik Malzeme Tarat",
                  iconData: WasteTheme.plasticIcon,
                  target: 50,
                  current: plasticCount,
                  color: WasteTheme.plasticColor,
                ),
                const SizedBox(height: 16),
                _buildAchievementCard(
                  context: context,
                  title: "50 Defa Cam Malzeme Tarat",
                  iconData: WasteTheme.glassIcon,
                  target: 50,
                  current: glassCount,
                  color: WasteTheme.glassColor,
                ),
                const SizedBox(height: 16),
                _buildAchievementCard(
                  context: context,
                  title: "50 Defa Metal Malzeme Tarat",
                  iconData: WasteTheme.metalIcon,
                  target: 50,
                  current: metalCount,
                  color: WasteTheme.metalColor,
                ),
                const SizedBox(height: 16),
                // 100'lük Başarılar
                _buildAchievementCard(
                  context: context,
                  title: "100 Defa Kağıt Malzeme Tarat",
                  iconData: WasteTheme.paperBoxIcon,
                  target: 100,
                  current: paperCount,
                  color: WasteTheme.paperColor,
                ),
                const SizedBox(height: 16),
                _buildAchievementCard(
                  context: context,
                  title: "100 Defa Plastik Malzeme Tarat",
                  iconData: WasteTheme.plasticBottleIcon,
                  target: 100,
                  current: plasticCount,
                  color: WasteTheme.plasticColor,
                ),
                const SizedBox(height: 16),
                _buildAchievementCard(
                  context: context,
                  title: "100 Defa Cam Malzeme Tarat",
                  iconData: WasteTheme.glassJarIcon,
                  target: 100,
                  current: glassCount,
                  color: WasteTheme.glassColor,
                ),
                const SizedBox(height: 16),
                _buildAchievementCard(
                  context: context,
                  title: "100 Defa Metal Malzeme Tarat",
                  iconData: WasteTheme.metalCanIcon,
                  target: 100,
                  current: metalCount,
                  color: WasteTheme.metalColor,
                ),
                const SizedBox(height: 16),
                _buildAchievementCard(
                  context: context,
                  title: "10 Defa En Yakın Noktaya Ulaş",
                  iconData: Icons.map_outlined,
                  target: 10,
                  current: 3, // Şimdilik statik
                  color: Colors.green,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Veri yüklenemedi: $err')),
      ),
    );
  }

  Widget _buildDailyActivityCard(BuildContext context, WidgetRef ref, DailyTask dailyTask, int currentCount) {
    int target = dailyTask.target;
    bool isCompleted = currentCount >= target;
    double percent = (currentCount / target).clamp(0.0, 1.0);
    int displayCurrent = min(currentCount, target);

    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.transparent),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Günlük Aktivite",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "$target tane ${dailyTask.material} malzeme tarat",
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
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
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text("Yeni Görev", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    content: Text("Günlük görevinizi yenilemek istediğinize emin misiniz?", style: GoogleFonts.outfit()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("İptal", style: GoogleFonts.outfit(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(dailyTaskProvider.notifier).generateNewTask();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: Text("Yenile", style: GoogleFonts.outfit(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 16, color: Colors.blue),
              label: Text("Yeni Görev", style: GoogleFonts.outfit(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTaskCard(BuildContext context, WeeklyTask task) {
    bool isCompleted = task.isCompleted;
    double percent = (task.currentCount / task.target).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCompleted ? Colors.blue.shade200 : Colors.transparent),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.blue, size: 20),
            ],
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
                  progressColor: Colors.blue,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "(${task.currentCount}/${task.target})",
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard({
    required BuildContext context,
    required String title,
    required IconData iconData,
    required int target,
    required int current,
    required Color color,
  }) {
    bool isCompleted = current >= target;
    double progress = current / target;

    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? color.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCompleted ? Border.all(color: color.withValues(alpha: 0.5), width: 2) : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          if (isCompleted)
             BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isCompleted ? color.withValues(alpha: 0.2) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  iconData,
                  size: 28,
                  color: isCompleted ? color : Colors.grey.shade500,
                ),
                if (isCompleted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle, color: color, size: 16),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.black87 : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                if (isCompleted)
                  Text(
                    "Tamamlandı!",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: LinearPercentIndicator(
                          lineHeight: 6.0,
                          percent: progress.clamp(0.0, 1.0),
                          animation: true,
                          barRadius: const Radius.circular(3),
                          progressColor: color,
                          backgroundColor: Colors.grey.shade200,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "$current/$target",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

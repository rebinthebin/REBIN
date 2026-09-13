import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bin_database_service.dart';
import '../providers/statistics_provider.dart';

class DailyTask {
  final String material;
  final int target;
  final int currentCount;
  final bool isCompleted;

  DailyTask({
    required this.material,
    required this.target,
    this.currentCount = 0,
    this.isCompleted = false,
  });

  DailyTask copyWith({
    String? material,
    int? target,
    int? currentCount,
    bool? isCompleted,
  }) {
    return DailyTask(
      material: material ?? this.material,
      target: target ?? this.target,
      currentCount: currentCount ?? this.currentCount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class DailyTaskNotifier extends AsyncNotifier<DailyTask> {
  final List<String> _materials = ['plastik', 'cam', 'kağıt', 'metal'];
  final List<int> _targets = [3, 5, 8, 10];
  final Random _random = Random();
  final _db = BinDatabaseService.instance;

  @override
  Future<DailyTask> build() async {
    return await _loadPersistedTask();
  }

  Future<DailyTask> _loadPersistedTask() async {
    final activeTask = await _db.getActiveTask();
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (activeTask != null) {
      final material = activeTask['material'] as String;
      final target = activeTask['target'] as int;
      final lastReset = activeTask['last_reset'] as String?;
      bool isCompleted = (activeTask['is_completed'] as int) == 1;

      // Eğer gün değiştiyse, isCompleted'ı sıfırla
      if (lastReset != today) {
        isCompleted = false;
        // Veritabanını güncelle: is_completed = 0 ve last_reset = today
        // setActiveTask metodunu tekrar çağırarak hem tarihi güncelleyip hem de is_completed'ı sıfırlayabiliriz
        await _db.setActiveTask(material, target);
      }

      final count = await _db.getDailyCount(material);
      return DailyTask(
        material: material,
        target: target,
        currentCount: count,
        isCompleted: isCompleted,
      );
    } else {
      const defaultMaterial = 'plastik';
      const defaultTarget = 3;
      await _db.setActiveTask(defaultMaterial, defaultTarget);
      final count = await _db.getDailyCount(defaultMaterial);
      return DailyTask(
        material: defaultMaterial,
        target: defaultTarget,
        currentCount: count,
        isCompleted: false,
      );
    }
  }

  Future<void> generateNewTask() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final String randomMaterial = _materials[_random.nextInt(_materials.length)];
      final int randomTarget = _targets[_random.nextInt(_targets.length)];
      
      // SQLite'a aktif görevi kaydet
      await _db.setActiveTask(randomMaterial, randomTarget);
      // TÜM günlük ilerlemeleri SIFIRLA (Yeni görev taze başlar)
      await _db.resetAllDailyTasks();
      
      return DailyTask(
        material: randomMaterial,
        target: randomTarget,
        currentCount: 0,
        isCompleted: false,
      );
    });
  }

  Future<void> incrementCount(String scannedMaterial) async {
    final currentTask = state.value;
    if (currentTask == null) return;

    // Eğer taranan malzeme günlük görevle eşleşiyorsa ilerlemeyi işle
    if (currentTask.material.toLowerCase() == scannedMaterial.toLowerCase()) {
      await _db.incrementDailyCount(currentTask.material);
      final newCount = await _db.getDailyCount(currentTask.material);

      bool newlyCompleted = false;
      if (!currentTask.isCompleted && newCount >= currentTask.target) {
        // Görev ilk kez tamamlanıyor
        await _db.setTaskCompleted();
        // NOT: _db.setTaskCompleted zaten UserStaticsDatabase.instance.incrementStatic('daily_tasks') çağırıyor.
        ref.invalidate(statisticsProvider);
        newlyCompleted = true;
      }

      state = AsyncData(currentTask.copyWith(
        currentCount: newCount,
        isCompleted: currentTask.isCompleted || newlyCompleted,
      ));
    } else {
      // Görevle eşleşmese bile veritabanındaki (daily_tasks tablosu) genel sayacı artır
      await _db.incrementDailyCount(scannedMaterial);
    }
  }

  Future<void> refreshCount() async {
    final currentTask = state.value;
    if (currentTask == null) return;

    final count = await _db.getDailyCount(currentTask.material);
    state = AsyncData(currentTask.copyWith(currentCount: count));
  }
}

final dailyTaskProvider = AsyncNotifierProvider<DailyTaskNotifier, DailyTask>(() {
  return DailyTaskNotifier();
});

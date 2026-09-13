import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bin_database_service.dart';
import '../providers/statistics_provider.dart';

class WeeklyTask {
  final String taskKey;
  final String title;
  final int target;
  final int currentCount;
  final bool isCompleted;

  WeeklyTask({
    required this.taskKey,
    required this.title,
    required this.target,
    this.currentCount = 0,
    this.isCompleted = false,
  });

  WeeklyTask copyWith({
    String? taskKey,
    String? title,
    int? target,
    int? currentCount,
    bool? isCompleted,
  }) {
    return WeeklyTask(
      taskKey: taskKey ?? this.taskKey,
      title: title ?? this.title,
      target: target ?? this.target,
      currentCount: currentCount ?? this.currentCount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class WeeklyTaskNotifier extends AsyncNotifier<List<WeeklyTask>> {
  final _db = BinDatabaseService.instance;

  @override
  Future<List<WeeklyTask>> build() async {
    return await _loadTasks();
  }

  Future<List<WeeklyTask>> _loadTasks() async {
    final tasksData = await _db.getWeeklyTasks();
    final now = DateTime.now();
    final currentMonday = _getMostRecentMonday(now);
    final mondayStr = "${currentMonday.year}-${currentMonday.month.toString().padLeft(2, '0')}-${currentMonday.day.toString().padLeft(2, '0')}";

    if (tasksData.isEmpty) {
      return await _initTasks(mondayStr);
    }

    // Check if reset is needed
    final firstTask = tasksData.first;
    final lastReset = firstTask['last_reset'] as String;
    if (lastReset != mondayStr) {
      return await _initTasks(mondayStr);
    }

    return tasksData.map((data) {
      final key = data['task_key'] as String;
      return WeeklyTask(
        taskKey: key,
        title: key == 'view_public' ? '3 kez Topluma Açık kutu görüntüle' : '1 kez Kutu Boşalt',
        target: data['target'] as int,
        currentCount: data['current_count'] as int,
        isCompleted: (data['is_completed'] as int) == 1,
      );
    }).toList();
  }

  Future<List<WeeklyTask>> _initTasks(String mondayStr) async {
    final initialTasks = [
      WeeklyTask(taskKey: 'view_public', title: '3 kez Topluma Açık kutu görüntüle', target: 3),
      WeeklyTask(taskKey: 'empty_bin', title: '1 kez Kutu Boşalt', target: 1),
    ];

    for (var task in initialTasks) {
      await _db.updateWeeklyTask(task.taskKey, 0, task.target, 0, mondayStr);
    }

    return initialTasks;
  }

  DateTime _getMostRecentMonday(DateTime date) {
    int daysToSubtract = (date.weekday - 1);
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysToSubtract));
  }

  Future<void> incrementTask(String key) async {
    final currentTasks = state.value;
    if (currentTasks == null) return;

    final taskIndex = currentTasks.indexWhere((t) => t.taskKey == key);
    if (taskIndex == -1) return;

    final task = currentTasks[taskIndex];
    if (task.isCompleted) return;

    await _db.incrementWeeklyTask(key);
    
    // UI'ı güncellemek için tekrar yükle (basitlik için)
    state = AsyncData(await _loadTasks());
    
    // Eğer bir görev tamamlandıysa istatistikleri yenile
    if (state.value![taskIndex].isCompleted) {
      ref.invalidate(statisticsProvider);
    }
  }
}

final weeklyTaskProvider = AsyncNotifierProvider<WeeklyTaskNotifier, List<WeeklyTask>>(() {
  return WeeklyTaskNotifier();
});

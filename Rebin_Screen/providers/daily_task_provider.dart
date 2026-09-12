import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyTaskState {
  final int completedTasks;
  final int totalTasks;
  final double progress;

  const DailyTaskState({
    this.completedTasks = 0,
    this.totalTasks = 5,
    this.progress = 0.0,
  });
}

class DailyTaskNotifier extends StateNotifier<DailyTaskState> {
  DailyTaskNotifier() : super(const DailyTaskState());

  void incrementTask(String taskKey) {
    state = DailyTaskState(
      completedTasks: state.completedTasks + 1,
      totalTasks: state.totalTasks,
      progress: ((state.completedTasks + 1) / state.totalTasks).clamp(0.0, 1.0),
    );
  }
}

final dailyTaskProvider = StateNotifierProvider<DailyTaskNotifier, DailyTaskState>((ref) {
  return DailyTaskNotifier();
});

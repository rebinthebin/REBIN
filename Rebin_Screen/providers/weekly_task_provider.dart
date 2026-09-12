import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyTaskNotifier extends StateNotifier<int> {
  WeeklyTaskNotifier() : super(0);

  void incrementTask(String taskKey) {
    state = state + 1;
  }
}

final weeklyTaskProvider = StateNotifierProvider<WeeklyTaskNotifier, int>((ref) {
  return WeeklyTaskNotifier();
});

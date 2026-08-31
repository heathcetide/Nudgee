import 'dart:async';

import 'package:flutter/foundation.dart';

/// Type of an initialization task.
enum InitTaskType {
  /// Executed sequentially in registration order.
  sync,

  /// Executed concurrently with other async tasks.
  async,
}

/// A single startup task.
class InitTask {
  final String name;
  final InitTaskType type;
  final Future<void> Function() task;
  final Duration? timeout;
  final bool required;

  const InitTask({
    required this.name,
    required this.type,
    required this.task,
    this.timeout,
    this.required = true,
  });
}

/// Result of running all init tasks.
class InitResult {
  final bool success;
  final List<String> failedTasks;
  final Duration totalDuration;

  const InitResult({
    required this.success,
    required this.failedTasks,
    required this.totalDuration,
  });
}

/// Startup orchestrator.
///
/// Tasks of type [InitTaskType.async] are run in parallel, while
/// [InitTaskType.sync] tasks are run sequentially (in registration order)
/// after the async batch completes. Progress is exposed via notifiers so a
/// splash / loading screen can react in real time.
class AppInitializer {
  final List<InitTask> _tasks = [];

  /// Progress from 0.0 to 1.0.
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

  /// Name of the task currently being executed.
  final ValueNotifier<String> currentTaskNotifier = ValueNotifier<String>('');

  /// Register a task.
  void addTask(InitTask task) => _tasks.add(task);

  /// Execute all registered tasks.
  ///
  /// Async tasks run in parallel; sync tasks run sequentially afterwards.
  /// Returns an [InitResult] describing the outcome.
  Future<InitResult> runAll() async {
    final stopwatch = Stopwatch()..start();
    final failedTasks = <String>[];
    final total = _tasks.length;
    var completed = 0;

    void updateProgress() {
      progressNotifier.value = total == 0 ? 1.0 : completed / total;
    }

    Future<void> runOne(InitTask t) async {
      currentTaskNotifier.value = t.name;
      try {
        final future = t.task();
        if (t.timeout != null) {
          await future.timeout(t.timeout!);
        } else {
          await future;
        }
      } catch (e, st) {
        debugPrint('[AppInitializer] task "${t.name}" failed: $e\n$st');
        failedTasks.add(t.name);
        if (t.required) rethrow;
      } finally {
        completed++;
        updateProgress();
      }
    }

    try {
      // ── Async tasks (parallel) ────────────────────────────────────────
      final asyncTasks = _tasks.where((t) => t.type == InitTaskType.async).toList();
      if (asyncTasks.isNotEmpty) {
        await Future.wait(asyncTasks.map(runOne));
      }

      // ── Sync tasks (sequential) ───────────────────────────────────────
      for (final t in _tasks.where((t) => t.type == InitTaskType.sync)) {
        await runOne(t);
      }
    } catch (_) {
      // A required task failed — stop early.
    }

    stopwatch.stop();
    progressNotifier.value = 1.0;
    currentTaskNotifier.value = '';
    return InitResult(
      success: failedTasks.isEmpty,
      failedTasks: failedTasks,
      totalDuration: stopwatch.elapsed,
    );
  }

  /// Release notifier resources.
  void dispose() {
    progressNotifier.dispose();
    currentTaskNotifier.dispose();
  }
}

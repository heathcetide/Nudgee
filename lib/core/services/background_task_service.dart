import 'package:nudgee/core/services/logger_service.dart';

/// Execution constraints for a [BackgroundTask].
///
/// Mirrors the common subset of `workmanager`'s constraints so the
/// abstraction can be mapped onto it (or any other scheduler) later without
/// changing call sites.
class Constraints {
  /// Whether a network connection is required.
  final bool requiresNetwork;

  /// Whether the device must be charging.
  final bool requiresCharging;

  /// Whether the device must be idle.
  final bool requiresDeviceIdle;

  /// Minimum battery level required (0-100), or `null` for no constraint.
  final int? minimumBatteryLevel;

  const Constraints({
    this.requiresNetwork = false,
    this.requiresCharging = false,
    this.requiresDeviceIdle = false,
    this.minimumBatteryLevel,
  });
}

/// A unit of background work registered with [BackgroundTaskService].
class BackgroundTask {
  /// Unique name used to identify / cancel the task.
  final String name;

  /// The work to execute when the scheduler fires.
  final Future<void> Function() task;

  /// How often the task should run. `null` means run once.
  final Duration? frequency;

  /// Execution constraints.
  final Constraints? constraints;

  /// Convenience flag that sets [Constraints.requiresNetwork] when `true`.
  final bool requiresNetwork;

  const BackgroundTask({
    required this.name,
    required this.task,
    this.frequency,
    this.constraints,
    this.requiresNetwork = false,
  });
}

/// Abstract background-task scheduler.
///
/// The concrete scheduling backend (e.g. `workmanager`) is intentionally not
/// imported here. A platform implementation can be wired in behind this API
/// so that call sites remain stable. On unsupported platforms the methods are
/// safe no-ops logged via [LoggerService].
class BackgroundTaskService {
  BackgroundTaskService({LoggerService? logger}) : _logger = logger;

  final LoggerService? _logger;

  /// Tasks currently registered, keyed by [BackgroundTask.name].
  final Map<String, BackgroundTask> _tasks = {};

  /// Whether [init] has been called.
  bool _initialized = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Initialize the underlying scheduler. Safe to call multiple times.
  void init() {
    if (_initialized) return;
    _initialized = true;
    _logger?.i('BackgroundTaskService initialized', tag: 'bg_task');
  }

  // ── Registration ──────────────────────────────────────────────────────

  /// Register [task] with the scheduler.
  ///
  /// If a task with the same name already exists it is replaced.
  void registerTask(BackgroundTask task) {
    _tasks[task.name] = task;
    _logger?.d('Registered background task: ${task.name}', tag: 'bg_task');
    // TODO(chenting): delegate to a concrete scheduler (workmanager) once the
    // platform plugin is wired. The task is stored so it can be dispatched.
  }

  /// Cancel the task identified by [name].
  void cancelTask(String name) {
    _tasks.remove(name);
    _logger?.d('Cancelled background task: $name', tag: 'bg_task');
  }

  /// Cancel all registered tasks.
  void cancelAll() {
    _tasks.clear();
    _logger?.d('Cancelled all background tasks', tag: 'bg_task');
  }
}

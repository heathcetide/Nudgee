/// Agent scheduled task framework — unified abstraction for running
/// agent-powered tasks on a schedule.
///
/// Design:
/// - [ScheduledTaskConfig] (from agent JSON) defines schedule + prompt.
/// - [AgentTaskScheduler] manages all scheduled tasks, checks timers,
///   and dispatches execution via [AgentService].
/// - Dedup history is persisted via [SharedPrefsService].
/// - Results are delivered via:
///   1. Local notifications
///   2. TTS voice playback (optional)
///   3. Report saved to workspace + object storage (optional)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/scheduled_task_config.dart';
import 'package:nudgee/core/services/agent_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';
import 'package:nudgee/core/services/workspace_service.dart';
import 'package:nudgee/core/voice/voice.dart';

/// Manages scheduled agent tasks — checks timers, runs agents, handles
/// dedup, delivers notifications, TTS, and report storage.
///
/// Tasks are loaded from [AgentConfig.scheduledTask] — no hardcoded tasks.
class AgentTaskScheduler {
  final AgentService _agentService;
  final SharedPrefsService _prefs;
  final VoiceService? _voiceService;
  final WorkspaceService? _workspaceService;
  final QiniuStorageService? _qiniuService;
  final FlutterLocalNotificationsPlugin _notifications;

  /// Registered tasks: agentId -> entry.
  final Map<String, _ScheduledEntry> _tasks = {};
  Timer? _checkTimer;
  bool _running = false;

  /// Last run time per task key.
  final Map<String, DateTime> _lastRunTimes = {};

  /// Dedup history: prefix -> {key: timestamp_ms}.
  final Map<String, Map<String, int>> _dedupHistory = {};

  static const String _prefsDedupKey = 'agent_task_dedup';
  static const String _prefsLastRunKey = 'agent_task_lastrun';

  AgentTaskScheduler({
    required AgentService agentService,
    required SharedPrefsService prefs,
    VoiceService? voiceService,
    WorkspaceService? workspaceService,
    QiniuStorageService? qiniuService,
  })  : _agentService = agentService,
        _prefs = prefs,
        _voiceService = voiceService,
        _workspaceService = workspaceService,
        _qiniuService = qiniuService,
        _notifications = FlutterLocalNotificationsPlugin() {
    _initNotifications();
    _loadState();
  }

  // ── Registration ──────────────────────────────────────────────────────

  /// Registers a scheduled task from an [AgentConfig].
  void registerFromAgent(AgentConfig config) {
    final task = config.scheduledTask;
    if (task == null || !task.enabled) return;

    _tasks[config.id] = _ScheduledEntry(
      agentId: config.id,
      agentName: config.name,
      config: task,
    );
    debugPrint('[AgentTaskScheduler] Registered: ${config.id} '
        '(${config.name}) — ${task.frequency.name} at ${task.hours}');
  }

  /// Registers from multiple agent configs.
  void registerFromAgents(List<AgentConfig> configs) {
    for (final config in configs) {
      registerFromAgent(config);
    }
  }

  /// Unregisters a task by agent ID.
  void unregister(String agentId) {
    _tasks.remove(agentId);
  }

  /// All registered task entries.
  List<_ScheduledEntry> get tasks => _tasks.values.toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Starts the periodic check timer (every 1 minute).
  void start() {
    if (_running) return;
    _running = true;
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    debugPrint('[AgentTaskScheduler] Started with ${_tasks.length} task(s)');
  }

  /// Stops the scheduler.
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _running = false;
  }

  /// Manually triggers a task by agent ID.
  Future<TaskExecutionResult> runTaskNow(String agentId) async {
    final entry = _tasks[agentId];
    if (entry == null) {
      return TaskExecutionResult(
        taskId: agentId,
        executedAt: DateTime.now(),
        reply: '',
        success: false,
        error: 'Task not found: $agentId',
      );
    }
    return _executeTask(entry);
  }

  // ── Internal ──────────────────────────────────────────────────────────

  void _tick() {
    final now = DateTime.now();
    for (final entry in _tasks.values) {
      final key = entry.agentId;
      final lastRun = _lastRunTimes[key];
      if (_shouldRun(entry.config, now, lastRun)) {
        _executeTask(entry).then((result) {
          if (result.success) {
            _lastRunTimes[key] = now;
            _saveLastRunTime(key, now);
          }
        }).catchError((e) {
          debugPrint('[AgentTaskScheduler] Task ${entry.agentId} failed: $e');
        });
      }
    }
  }

  bool _shouldRun(ScheduledTaskConfig config, DateTime now, DateTime? lastRun) {
    switch (config.frequency) {
      case TaskFrequency.daily:
        if (!config.hours.contains(now.hour)) return false;
        if (lastRun == null) return true;
        return !_sameHour(lastRun, now);
      case TaskFrequency.weekly:
        if (!config.weekdays.contains(now.weekday)) return false;
        if (!config.hours.contains(now.hour)) return false;
        if (lastRun == null) return true;
        return !_sameHour(lastRun, now);
      case TaskFrequency.interval:
        final interval = Duration(seconds: config.intervalSeconds ?? 0);
        if (interval == Duration.zero) return false;
        if (lastRun == null) return true;
        return now.difference(lastRun) >= interval;
    }
  }

  bool _sameHour(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour;

  Future<TaskExecutionResult> _executeTask(_ScheduledEntry entry) async {
    final config = entry.config;
    debugPrint('[AgentTaskScheduler] Executing: ${entry.agentId}');

    final today = _formatDate(DateTime.now());
    final prompt = config.prompt.replaceAll('{date}', today);

    try {
      final reply = StringBuffer();
      final stream = _agentService.runAgent(entry.agentId, prompt);

      await for (final event in stream) {
        switch (event) {
          case ContentEvent(:final delta):
            reply.write(delta);
          case DoneEvent(:final finalReply):
            if (reply.isEmpty) reply.write(finalReply);
          case ErrorEvent(:final message):
            debugPrint('[AgentTaskScheduler] Agent error: $message');
          case _:
        }
      }

      final resultText = reply.toString();
      final processedKeys = _extractKeys(resultText, config.dedupPrefix);

      if (config.dedupPrefix != null && processedKeys.isNotEmpty) {
        _recordDedup(config.dedupPrefix!, processedKeys);
      }

      // 1. Notification.
      if (config.notify) {
        await _sendNotification(entry, resultText);
      }

      // 2. TTS.
      if (config.enableTts && _voiceService != null) {
        final ttsText = _extractSummary(resultText);
        if (ttsText.isNotEmpty) {
          _voiceService!.speak(ttsText).catchError((e) {
            debugPrint('[AgentTaskScheduler] TTS error: $e');
          });
        }
      }

      // 3. Save report.
      if (config.saveReport) {
        await _saveReport(entry, resultText);
      }

      debugPrint('[AgentTaskScheduler] Task ${entry.agentId} done: '
          '${resultText.length} chars');

      return TaskExecutionResult(
        taskId: entry.agentId,
        executedAt: DateTime.now(),
        reply: resultText,
        success: true,
        processedKeys: processedKeys,
      );
    } catch (e) {
      debugPrint('[AgentTaskScheduler] Task ${entry.agentId} exception: $e');
      return TaskExecutionResult(
        taskId: entry.agentId,
        executedAt: DateTime.now(),
        reply: '',
        success: false,
        error: e.toString(),
      );
    }
  }

  // ── TTS Summary ───────────────────────────────────────────────────────

  String _extractSummary(String report) {
    final lines = report.split('\n');
    final summaryLines = <String>[];
    bool inSummary = false;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('top 3') ||
          lower.contains('推荐') ||
          lower.contains('总结') ||
          lower.contains('summary') ||
          lower.contains('结论')) {
        inSummary = true;
      }
      if (inSummary) {
        summaryLines.add(line);
        if (summaryLines.length > 15) break;
      }
    }

    if (summaryLines.isEmpty) {
      summaryLines.addAll(lines.where((l) => l.trim().isNotEmpty).take(10));
    }

    var text = summaryLines.join('\n');
    text = text
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'\*{1,2}'), '')
        .replaceAll(RegExp(r'`{1,3}'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'^[\-\*]\s', multiLine: true), '');

    if (text.length > 500) {
      text = '${text.substring(0, 500)}...';
    }
    return text;
  }

  // ── Report Storage ────────────────────────────────────────────────────

  Future<void> _saveReport(_ScheduledEntry entry, String content) async {
    final config = entry.config;
    final basePath = config.reportPath ?? 'reports/${entry.agentId}';
    final today = _formatDate(DateTime.now());
    final fileName = '$today.md';
    final relativePath = p.join(basePath, fileName);

    // 1. Local workspace.
    if (_workspaceService != null && _workspaceService!.isInitialized) {
      try {
        await _workspaceService!.writeFile(relativePath, content);
        debugPrint('[AgentTaskScheduler] Report saved to workspace: $relativePath');
      } catch (e) {
        debugPrint('[AgentTaskScheduler] Workspace save error: $e');
      }
    } else {
      try {
        final baseDir = await getApplicationDocumentsDirectory();
        final file = File(p.join(baseDir.path, 'workspace', relativePath));
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
        debugPrint('[AgentTaskScheduler] Report saved: ${file.path}');
      } catch (e) {
        debugPrint('[AgentTaskScheduler] Fallback save error: $e');
      }
    }

    // 2. Object storage (Qiniu).
    if (_qiniuService != null && _qiniuService!.isConfigured) {
      try {
        final bytes = Uint8List.fromList(utf8.encode(content));
        final key = 'reports/${entry.agentId}/$fileName';
        final url = await _qiniuService!.uploadBytes(key, bytes);
        if (url != null) {
          debugPrint('[AgentTaskScheduler] Report uploaded: $url');
        }
      } catch (e) {
        debugPrint('[AgentTaskScheduler] Upload error: $e');
      }
    }
  }

  // ── Dedup ─────────────────────────────────────────────────────────────

  List<String> _extractKeys(String reply, String? prefix) {
    if (prefix == null) return [];
    final regex = RegExp(r'[\w.-]+/[\w.-]+');
    return regex
        .allMatches(reply)
        .map((m) => m.group(0)!)
        .where((s) => !s.contains(' ') && s.length > 3)
        .toSet()
        .toList();
  }

  void _recordDedup(String prefix, List<String> keys) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _dedupHistory[prefix] ??= {};
    for (final key in keys) {
      _dedupHistory[prefix]![key] = now;
    }
    _saveDedupHistory();
  }

  void _loadState() {
    try {
      final dedupJson = _prefs.getString(_prefsDedupKey);
      if (dedupJson != null) {
        final map = jsonDecode(dedupJson) as Map<String, dynamic>;
        _dedupHistory.clear();
        for (final entry in map.entries) {
          _dedupHistory[entry.key] = (entry.value as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toInt()));
        }
      }
      final lastRunJson = _prefs.getString(_prefsLastRunKey);
      if (lastRunJson != null) {
        final map = jsonDecode(lastRunJson) as Map<String, dynamic>;
        map.forEach((key, value) {
          _lastRunTimes[key] =
              DateTime.fromMillisecondsSinceEpoch((value as num).toInt());
        });
      }
    } catch (e) {
      debugPrint('[AgentTaskScheduler] Load state error: $e');
    }
  }

  void _saveDedupHistory() {
    try {
      _prefs.setString(_prefsDedupKey, jsonEncode(_dedupHistory));
    } catch (e) {
      debugPrint('[AgentTaskScheduler] Save dedup error: $e');
    }
  }

  void _saveLastRunTime(String taskId, DateTime time) {
    try {
      final map = <String, dynamic>{};
      for (final e in _lastRunTimes.entries) {
        map[e.key] = e.value.millisecondsSinceEpoch;
      }
      _prefs.setString(_prefsLastRunKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[AgentTaskScheduler] Save lastRun error: $e');
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────

  Future<void> _initNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _notifications.initialize(settings);
    } catch (e) {
      debugPrint('[AgentTaskScheduler] Notification init error: $e');
    }
  }

  Future<void> _sendNotification(_ScheduledEntry entry, String reply) async {
    try {
      final id = entry.agentId.hashCode & 0x7FFFFFFF;
      final title = '📊 ${entry.agentName}';
      final body = reply.length > 200 ? '${reply.substring(0, 200)}...' : reply;

      const androidDetails = AndroidNotificationDetails(
        'agent_scheduled_tasks',
        'Agent 定时任务',
        channelDescription: 'Agent 定时任务执行结果通知',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(id, title, body, details);
    } catch (e) {
      debugPrint('[AgentTaskScheduler] Notification error: $e');
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void dispose() {
    stop();
  }
}

class _ScheduledEntry {
  final String agentId;
  final String agentName;
  final ScheduledTaskConfig config;

  const _ScheduledEntry({
    required this.agentId,
    required this.agentName,
    required this.config,
  });
}

class TaskExecutionResult {
  final String taskId;
  final DateTime executedAt;
  final String reply;
  final bool success;
  final String? error;
  final List<String> processedKeys;

  TaskExecutionResult({
    required this.taskId,
    required this.executedAt,
    required this.reply,
    required this.success,
    this.error,
    this.processedKeys = const [],
  });
}

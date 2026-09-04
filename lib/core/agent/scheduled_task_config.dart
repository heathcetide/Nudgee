/// Scheduled task configuration — embedded in [AgentConfig] JSON.
///
/// Allows defining agent scheduled tasks directly in the agent's JSON file
/// instead of hardcoding them in Dart.
///
/// JSON schema:
/// ```json
/// "scheduled_task": {
///   "enabled": true,
///   "hours": [8, 16],
///   "weekdays": [],
///   "interval_seconds": null,
///   "prompt": "请执行今日分析任务...",
///   "notify": true,
///   "save_to_chat": false,
///   "dedup_prefix": "oss-analyzed",
///   "dedup_ttl_days": 14,
///   "enable_tts": true,
///   "save_report": true,
///   "report_path": "reports/oss-analysis"
/// }
/// ```

/// Schedule frequency for a task.
enum TaskFrequency {
  daily,
  weekly,
  interval,
}

/// Configuration for a scheduled agent task, loaded from JSON.
class ScheduledTaskConfig {
  /// Whether the task is enabled.
  final bool enabled;

  /// Hours of the day to run (0-23).
  final List<int> hours;

  /// Weekdays to run (1=Monday, 7=Sunday). Empty = every day.
  final List<int> weekdays;

  /// Interval in seconds (for interval mode). If non-null, uses interval mode.
  final int? intervalSeconds;

  /// The prompt template to send to the agent.
  /// `{date}` is replaced with today's date.
  final String prompt;

  /// Whether to send a local notification with the result.
  final bool notify;

  /// Whether to save the result to chat history.
  final bool saveToChat;

  /// Dedup prefix — if set, analyzed items are tracked to avoid duplicates.
  final String? dedupPrefix;

  /// Dedup TTL in days.
  final int dedupTtlDays;

  /// Whether to speak the summary via TTS after completion.
  final bool enableTts;

  /// Whether to save a report document to workspace + object storage.
  final bool saveReport;

  /// Base path in the workspace for saved reports.
  /// The final path will be `{reportPath}/{date}.md`.
  final String? reportPath;

  const ScheduledTaskConfig({
    this.enabled = true,
    required this.hours,
    this.weekdays = const [],
    this.intervalSeconds,
    required this.prompt,
    this.notify = true,
    this.saveToChat = false,
    this.dedupPrefix,
    this.dedupTtlDays = 14,
    this.enableTts = false,
    this.saveReport = false,
    this.reportPath,
  });

  /// Determines the frequency mode from the config.
  TaskFrequency get frequency {
    if (intervalSeconds != null) return TaskFrequency.interval;
    if (weekdays.isNotEmpty) return TaskFrequency.weekly;
    return TaskFrequency.daily;
  }

  /// Creates from JSON.
  factory ScheduledTaskConfig.fromJson(Map<String, dynamic> json) {
    return ScheduledTaskConfig(
      enabled: json['enabled'] as bool? ?? true,
      hours: (json['hours'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      weekdays: (json['weekdays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      intervalSeconds: json['interval_seconds'] as int?,
      prompt: json['prompt'] as String? ?? '',
      notify: json['notify'] as bool? ?? true,
      saveToChat: json['save_to_chat'] as bool? ?? false,
      dedupPrefix: json['dedup_prefix'] as String?,
      dedupTtlDays: json['dedup_ttl_days'] as int? ?? 14,
      enableTts: json['enable_tts'] as bool? ?? false,
      saveReport: json['save_report'] as bool? ?? false,
      reportPath: json['report_path'] as String?,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hours': hours,
        'weekdays': weekdays,
        if (intervalSeconds != null) 'interval_seconds': intervalSeconds,
        'prompt': prompt,
        'notify': notify,
        'save_to_chat': saveToChat,
        if (dedupPrefix != null) 'dedup_prefix': dedupPrefix,
        'dedup_ttl_days': dedupTtlDays,
        'enable_tts': enableTts,
        'save_report': saveReport,
        if (reportPath != null) 'report_path': reportPath,
      };
}

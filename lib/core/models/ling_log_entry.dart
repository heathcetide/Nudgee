/// Log severity level used throughout the logging subsystem.
enum LingLogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  fatal;

  /// Short uppercase label used in serialized log lines.
  String get label => name.toUpperCase();

  /// Parse a [LingLogLevel] from its [name]; falls back to [info].
  static LingLogLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'verbose':
        return LingLogLevel.verbose;
      case 'debug':
        return LingLogLevel.debug;
      case 'info':
        return LingLogLevel.info;
      case 'warning':
        return LingLogLevel.warning;
      case 'error':
        return LingLogLevel.error;
      case 'fatal':
        return LingLogLevel.fatal;
      default:
        return LingLogLevel.info;
    }
  }
}

/// A structured log entry produced by [LoggerService].
///
/// Carries enough context to be persisted to a log file and/or uploaded
/// to a remote log-reporting endpoint.
class LingLogEntry {
  final DateTime timestamp;
  final LingLogLevel level;
  final String tag;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? extra;

  LingLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
    this.extra,
  });

  /// Serialize to a JSON map suitable for HTTP upload or file storage.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'tag': tag,
        'message': message,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (extra != null && extra!.isNotEmpty) 'extra': extra,
      };

  /// Deserialize from a JSON map.
  factory LingLogEntry.fromJson(Map<String, dynamic> json) => LingLogEntry(
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        level: LingLogLevel.fromString(json['level'] as String?),
        tag: json['tag'] as String? ?? '',
        message: json['message'] as String? ?? '',
        error: json['error'],
        stackTrace: json['stackTrace'] != null
            ? StackTrace.fromString(json['stackTrace'] as String)
            : null,
        extra: json['extra'] is Map<String, dynamic>
            ? json['extra'] as Map<String, dynamic>
            : null,
      );

  /// Format as a single log line for file persistence.
  ///
  /// Format: `[2024-01-15 10:30:45.123] [LEVEL] [TAG] message`
  String toLogLine() {
    final buffer = StringBuffer('[${_formatTimestamp(timestamp)}] ')
      ..write('[${level.label}] ')
      ..write('[$tag] ')
      ..write(message);
    if (error != null) {
      buffer.write(' | error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    if (extra != null && extra!.isNotEmpty) {
      buffer.write(' | extra: $extra');
    }
    return buffer.toString();
  }

  static String _formatTimestamp(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}.${three(dt.millisecond)}';
  }
}

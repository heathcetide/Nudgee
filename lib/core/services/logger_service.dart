import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'package:nudgee/core/config/app_config.dart';
import 'package:nudgee/core/models/ling_log_entry.dart';
import 'package:nudgee/core/services/log_file_service.dart';
import 'package:nudgee/core/services/log_reporter_service.dart';

/// Centralized logging service wrapping the `logger` package.
///
/// In production, only warnings and errors are emitted.
/// In dev/staging, debug and info logs are also shown.
///
/// Supports tagged logging via the optional `tag` parameter, structured
/// `extra` payloads, file persistence via [LogFileService], and remote
/// reporting via [LogReporterService].
///
/// All optional parameters (`tag`, `error`, `stackTrace`, `extra`) are named
/// to keep call sites self-documenting. Legacy positional `error`/`stackTrace`
/// callers have been migrated to named parameters.
class LoggerService {
  late final Logger _logger;

  /// Optional file-persistence backend.
  LogFileService? logFileService;

  /// Optional remote-reporting backend.
  LogReporterService? logReporterService;

  LoggerService({this.logFileService, this.logReporterService}) {
    _logger = Logger(
      level: AppConfig.enableVerboseLogging ? Level.debug : Level.warning,
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 8,
        lineLength: 100,
        colors: true,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  // ── Logging methods ───────────────────────────────────────────────────

  /// Verbose log.
  void v(
    String message, {
    String tag = 'app',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) =>
      _log(LingLogLevel.verbose, tag, message,
          error: error, stackTrace: stackTrace, extra: extra);

  /// Debug log.
  void d(
    dynamic message, {
    String tag = 'app',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) =>
      _log(LingLogLevel.debug, tag, message?.toString() ?? '',
          error: error, stackTrace: stackTrace, extra: extra);

  /// Info log.
  void i(
    dynamic message, {
    String tag = 'app',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) =>
      _log(LingLogLevel.info, tag, message?.toString() ?? '',
          error: error, stackTrace: stackTrace, extra: extra);

  /// Warning log.
  void w(
    dynamic message, {
    String tag = 'app',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) =>
      _log(LingLogLevel.warning, tag, message?.toString() ?? '',
          error: error, stackTrace: stackTrace, extra: extra);

  /// Error log.
  void e(
    dynamic message, {
    String tag = 'app',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) =>
      _log(LingLogLevel.error, tag, message?.toString() ?? '',
          error: error, stackTrace: stackTrace, extra: extra);

  /// Fatal log (legacy alias preserved for backward compatibility).
  void wtf(
    dynamic message, {
    String tag = 'app',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) =>
      _log(LingLogLevel.fatal, tag, message?.toString() ?? '',
          error: error, stackTrace: stackTrace, extra: extra);

  // ── Error capture ─────────────────────────────────────────────────────

  /// Record an arbitrary [error] with its [stackTrace].
  void recordError(dynamic error, StackTrace? stackTrace, {String tag = 'error'}) {
    _log(
      LingLogLevel.error,
      tag,
      error.toString(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Register the global [FlutterError.onError] hook so framework-level
  /// errors are funneled through this logger.
  void recordFlutterError() {
    FlutterError.onError = (FlutterErrorDetails details) {
      _log(
        LingLogLevel.error,
        'flutter',
        details.exceptionAsString(),
        error: details.exception,
        stackTrace: details.stack,
        extra: details.context != null ? {'context': details.context.toString()} : null,
      );
      // Preserve default behavior in debug mode.
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };
  }

  // ── Internal ──────────────────────────────────────────────────────────

  void _log(
    LingLogLevel level,
    String tag,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    // Console output via the underlying logger package.
    switch (level) {
      case LingLogLevel.verbose:
        _logger.t(message, error: error, stackTrace: stackTrace);
        break;
      case LingLogLevel.debug:
        _logger.d(message, error: error, stackTrace: stackTrace);
        break;
      case LingLogLevel.info:
        _logger.i(message, error: error, stackTrace: stackTrace);
        break;
      case LingLogLevel.warning:
        _logger.w(message, error: error, stackTrace: stackTrace);
        break;
      case LingLogLevel.error:
        _logger.e(message, error: error, stackTrace: stackTrace);
        break;
      case LingLogLevel.fatal:
        _logger.f(message, error: error, stackTrace: stackTrace);
        break;
    }

    final entry = LingLogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );

    // Persist to file (fire-and-forget).
    logFileService?.write(entry);

    // Enqueue for remote reporting (errors/fatals only).
    logReporterService?.enqueue(entry);
  }
}

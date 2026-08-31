import 'package:flutter/foundation.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/logger_service.dart';
import 'package:nudgee/core/services/log_reporter_service.dart';

/// Global crash / exception handler.
///
/// Wires up [FlutterError.onError] and [PlatformDispatcher.onError] so that
/// framework and platform-level errors are funneled through [LoggerService]
/// and [LogReporterService]. Zone-guarded errors (from `runZonedGuarded`)
/// should be forwarded to [onZoneError].
class CrashHandler {
  CrashHandler._();

  static final CrashHandler instance = CrashHandler._();

  LoggerService? get _logger => sl.isRegistered<LoggerService>() ? sl<LoggerService>() : null;
  LogReporterService? get _reporter =>
      sl.isRegistered<LogReporterService>() ? sl<LogReporterService>() : null;

  /// Install global error handlers.
  ///
  /// Call once during app startup, before `runApp`.
  void init() {
    // Framework errors (rendering, layout, assertions, etc.).
    FlutterError.onError = (FlutterErrorDetails details) {
      recordError(details.exception, details.stack ?? StackTrace.current,
          fatal: details.silent != true);
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Errors that escape Flutter's widget tree (isolates, platform channels).
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack);
      return true;
    };
  }

  /// Record an arbitrary error with its stack trace.
  ///
  /// Logs locally via [LoggerService] and enqueues for remote reporting via
  /// [LogReporterService] (when registered).
  void recordError(dynamic error, StackTrace stack, {bool fatal = false}) {
    final logger = _logger;
    if (logger != null) {
      logger.recordError(error, stack, tag: fatal ? 'fatal' : 'error');
    } else {
      debugPrint('[CrashHandler] $error\n$stack');
    }
    // LogReporterService enqueues automatically via LoggerService._log,
    // but ensure it is started when present.
    _reporter?.reportNow();
  }

  /// Handler for errors caught by `runZonedGuarded`.
  void onZoneError(dynamic error, StackTrace stack) {
    recordError(error, stack, fatal: true);
  }
}

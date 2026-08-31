import 'package:flutter/scheduler.dart';

import 'package:nudgee/core/services/analytics_service.dart';
import 'package:nudgee/core/services/logger_service.dart';

/// Monitors frame rendering times and reports jank (frames exceeding 16ms).
///
/// Uses [SchedulerBinding.addTimingsCallback] to receive frame timing updates
/// after they are rendered. Frames exceeding [jankThreshold] are reported to
/// [AnalyticsService] and [LoggerService].
///
/// Usage:
///   final monitor = FrameTimingMonitorService(analytics: sl(), logger: sl());
///   monitor.start();
///   // ... app runs ...
///   monitor.stop();
class FrameTimingMonitorService {
  FrameTimingMonitorService({
    required this.analytics,
    required this.logger,
    this.jankThreshold = const Duration(milliseconds: 16),
    this.severeJankThreshold = const Duration(milliseconds: 32),
  });

  final AnalyticsService analytics;
  final LoggerService logger;

  /// Wall-duration threshold above which a frame is considered janky.
  final Duration jankThreshold;

  /// Wall-duration threshold above which a frame is considered severely janky.
  final Duration severeJankThreshold;

  bool _running = false;
  int _totalFrames = 0;
  int _jankFrames = 0;
  int _severeJankFrames = 0;

  /// Whether the monitor is currently active.
  bool get isRunning => _running;

  /// Total frames observed since [start].
  int get totalFrames => _totalFrames;

  /// Janky frames (exceeded [jankThreshold]) since [start].
  int get jankFrames => _jankFrames;

  /// Severely janky frames (exceeded [severeJankThreshold]) since [start].
  int get severeJankFrames => _severeJankFrames;

  /// Start monitoring frame timings.
  void start() {
    if (_running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Stop monitoring frame timings.
  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final frame in timings) {
      _totalFrames++;
      final duration = frame.totalSpan;
      if (duration > severeJankThreshold) {
        _severeJankFrames++;
        _jankFrames++;
        logger.w(
          'Severe jank: ${duration.inMilliseconds}ms '
          '(build: ${frame.buildDuration.inMilliseconds}ms, '
          'raster: ${frame.rasterDuration.inMilliseconds}ms)',
          tag: 'FrameTiming',
        );
        analytics.trackError(
          'frame_jank_severe',
          properties: {
            'total_ms': duration.inMilliseconds,
            'build_ms': frame.buildDuration.inMilliseconds,
            'raster_ms': frame.rasterDuration.inMilliseconds,
          },
        );
      } else if (duration > jankThreshold) {
        _jankFrames++;
        logger.d(
          'Jank: ${duration.inMilliseconds}ms',
          tag: 'FrameTiming',
        );
        analytics.trackError(
          'frame_jank',
          properties: {
            'total_ms': duration.inMilliseconds,
            'build_ms': frame.buildDuration.inMilliseconds,
            'raster_ms': frame.rasterDuration.inMilliseconds,
          },
        );
      }
    }
  }

  /// Reset all counters.
  void reset() {
    _totalFrames = 0;
    _jankFrames = 0;
    _severeJankFrames = 0;
  }

  /// Dispose and stop monitoring.
  void dispose() {
    stop();
  }
}

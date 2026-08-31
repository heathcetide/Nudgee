import 'dart:async';

import 'package:nudgee/core/network/api_client.dart';

import 'package:nudgee/core/models/ling_log_entry.dart';

/// Collects error/fatal [LingLogEntry]s and uploads them in batches to a
/// remote endpoint.
///
/// Upload is triggered either on a periodic [Timer] (default 60s) or when
/// the in-memory queue reaches [threshold] entries (default 20). Failed
/// uploads retain their entries for the next retry cycle.
class LogReporterService {
  LogReporterService({
    required ApiClient apiClient,
    Duration interval = const Duration(seconds: 60),
    this.threshold = 20,
    String endpoint = '/api/logs/report',
  })  : _apiClient = apiClient,
        _interval = interval,
        _endpoint = endpoint;

  final ApiClient _apiClient;
  Duration _interval;
  String _endpoint;
  final int threshold;

  final List<LingLogEntry> _queue = [];
  Timer? _timer;
  bool _uploading = false;

  /// Begin the periodic upload timer.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => reportNow());
  }

  /// Stop the periodic upload timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Configure the upload interval (restarts the timer if running).
  void setInterval(Duration interval) {
    _interval = interval;
    if (_timer != null) start();
  }

  /// Configure the remote endpoint path.
  void setEndpoint(String endpoint) => _endpoint = endpoint;

  /// Enqueue an entry for upload; triggers an immediate upload when the
  /// threshold is reached.
  void enqueue(LingLogEntry entry) {
    if (entry.level != LingLogLevel.error && entry.level != LingLogLevel.fatal) {
      return;
    }
    _queue.add(entry);
    if (_queue.length >= threshold) {
      reportNow();
    }
  }

  /// Manually trigger an upload of the current queue.
  Future<void> reportNow() async {
    if (_uploading || _queue.isEmpty) return;
    _uploading = true;
    final batch = List<LingLogEntry>.from(_queue);
    try {
      await _apiClient.post(
        _endpoint,
        data: {
          'logs': batch.map((e) => e.toJson()).toList(),
        },
      );
      // Success — remove uploaded entries.
      _queue.removeWhere(batch.contains);
    } catch (_) {
      // Failure — keep entries for next retry.
    } finally {
      _uploading = false;
    }
  }

  /// Release resources.
  void dispose() {
    stop();
    _queue.clear();
  }
}

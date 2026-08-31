import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:nudgee/core/network/api_client.dart';

/// Status of a [DownloadTask] in the download lifecycle.
enum DownloadStatus {
  /// No active operation.
  idle,

  /// Currently downloading bytes from the server.
  downloading,

  /// Manually paused by the user.
  paused,

  /// Successfully completed.
  completed,

  /// Failed due to a network or server error.
  failed,

  /// Cancelled by the user or system.
  cancelled,
}

/// Represents a single file download operation tracked by [DownloadService].
///
/// Immutable value object — use [copyWith] to produce updated instances
/// as the download progresses. Registered in the download queue and surfaced
/// to the UI via [LingDownloadProgress].
class DownloadTask {
  /// Unique identifier.
  final String id;

  /// Source URL to download from.
  final String url;

  /// Absolute local path where the file is / will be saved.
  final String savePath;

  /// Display name of the file (defaults to the last URL segment).
  final String? fileName;

  /// Total size of the file in bytes (0 if unknown).
  final int totalBytes;

  /// Number of bytes already downloaded.
  final int downloadedBytes;

  /// Current lifecycle status.
  final DownloadStatus status;

  /// Download progress as a fraction in `[0.0, 1.0]`.
  final double progress;

  /// When the task was created.
  final DateTime createdAt;

  /// Error message when [status] is [DownloadStatus.failed].
  final String? error;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.savePath,
    this.fileName,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    required this.createdAt,
    this.error,
  });

  /// Whether the task is in a terminal state.
  bool get isFinished =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.failed ||
      status == DownloadStatus.cancelled;

  /// Whether the task is actively transferring bytes.
  bool get isDownloading => status == DownloadStatus.downloading;

  /// Human-readable progress percentage (e.g. `42`).
  int get percent => (progress * 100).round().clamp(0, 100);

  /// Produce a new [DownloadTask] with selective field overrides.
  DownloadTask copyWith({
    String? id,
    String? url,
    String? savePath,
    String? fileName,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    double? progress,
    DateTime? createdAt,
    String? error,
  }) =>
      DownloadTask(
        id: id ?? this.id,
        url: url ?? this.url,
        savePath: savePath ?? this.savePath,
        fileName: fileName ?? this.fileName,
        totalBytes: totalBytes ?? this.totalBytes,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        createdAt: createdAt ?? this.createdAt,
        error: error ?? this.error,
      );
}

/// Centralized file download service.
///
/// Wraps [ApiClient.download] with conveniences for progress reporting,
/// cancellation, pause / retry, and a simple in-memory download queue
/// surfaced to the UI via [tasksNotifier].
class DownloadService {
  DownloadService(this._api);

  final ApiClient _api;

  // ── Queue state ──────────────────────────────────────────────────────

  /// All known download tasks keyed by id.
  final Map<String, DownloadTask> _tasks = {};

  /// Active cancel tokens keyed by task id.
  final Map<String, CancelToken> _cancelTokens = {};

  /// Active stream controllers keyed by task id (for [watchTask]).
  final Map<String, StreamController<DownloadTask>> _controllers = {};

  /// Notifier that emits the current list of tasks (newest first).
  final ValueNotifier<List<DownloadTask>> tasksNotifier = ValueNotifier(const []);

  /// Read-only access to the current task list.
  List<DownloadTask> get tasks => tasksNotifier.value;

  // ── Public API ───────────────────────────────────────────────────────

  /// Start downloading [url] to [savePath].
  ///
  /// [onProgress] receives a fraction in `[0.0, 1.0]`. Returns the final
  /// [DownloadTask] (status `completed` on success, `failed`/`cancelled`
  /// otherwise).
  Future<DownloadTask> download(
    String url,
    String savePath, {
    String? fileName,
    Function(double progress)? onProgress,
  }) async {
    final id = _generateId();
    final name = fileName ?? _fileNameFromUrl(url);
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    final task = DownloadTask(
      id: id,
      url: url,
      savePath: savePath,
      fileName: name,
      createdAt: DateTime.now(),
    );
    _upsert(task);

    try {
      _upsert(task.copyWith(status: DownloadStatus.downloading));
      await _api.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final p = (received / total).clamp(0.0, 1.0);
          _upsert(
            task.copyWith(
              status: DownloadStatus.downloading,
              downloadedBytes: received,
              totalBytes: total,
              progress: p,
            ),
          );
          onProgress?.call(p);
        },
      );
      final done = _tasks[id]!.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: _tasks[id]!.totalBytes > 0
            ? _tasks[id]!.totalBytes
            : _tasks[id]!.downloadedBytes,
      );
      _upsert(done);
      return done;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        final cancelled = _tasks[id]!.copyWith(status: DownloadStatus.cancelled);
        _upsert(cancelled);
        return cancelled;
      }
      final failed = _tasks[id]!.copyWith(
        status: DownloadStatus.failed,
        error: e.message ?? 'Download failed',
      );
      _upsert(failed);
      return failed;
    } catch (e) {
      final failed = _tasks[id]!.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      _upsert(failed);
      return failed;
    } finally {
      _cancelTokens.remove(id);
    }
  }

  /// Cancel an active download by [taskId].
  void cancel(String taskId) {
    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
    final task = _tasks[taskId];
    if (task != null && !task.isFinished) {
      _upsert(task.copyWith(status: DownloadStatus.cancelled));
    }
    _cancelTokens.remove(taskId);
  }

  /// Pause a download by [taskId].
  ///
  /// Dio does not support true pause/resume natively — this cancels the
  /// in-flight request and marks the task as [DownloadStatus.paused]. Use
  /// [retry] to restart from scratch (range/resume support can be added
  /// later by extending [ApiClient.download] with `Range` headers).
  void pause(String taskId) {
    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
    final task = _tasks[taskId];
    if (task != null && !task.isFinished) {
      _upsert(task.copyWith(status: DownloadStatus.paused));
    }
    _cancelTokens.remove(taskId);
  }

  /// Retry a failed / paused / cancelled download by [taskId].
  Future<DownloadTask> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      throw ArgumentError('Unknown download task: $taskId');
    }
    _upsert(task.copyWith(status: DownloadStatus.idle, error: null, progress: 0.0));
    return download(task.url, task.savePath, fileName: task.fileName);
  }

  /// Remove a task from the queue. Cancels it first if still active.
  void removeTask(String taskId) {
    cancel(taskId);
    _tasks.remove(taskId);
    _controllers[taskId]?.close();
    _controllers.remove(taskId);
    _notify();
  }

  /// Remove all finished (completed / failed / cancelled) tasks.
  void clearFinished() {
    _tasks.removeWhere((_, t) => t.isFinished);
    _notify();
  }

  /// Get a task by [id], or `null` if unknown.
  DownloadTask? getTask(String taskId) => _tasks[taskId];

  /// Observe a single task as a stream of immutable snapshots.
  Stream<DownloadTask> watchTask(String taskId) {
    _controllers[taskId] ??= StreamController<DownloadTask>.broadcast();
    final controller = _controllers[taskId]!;
    if (_tasks[taskId] != null) controller.add(_tasks[taskId]!);
    return controller.stream;
  }

  // ── Private ──────────────────────────────────────────────────────────

  String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now.toRadixString(36).toUpperCase();
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments;
    if (segments != null && segments.isNotEmpty) {
      return segments.last;
    }
    return 'download';
  }

  void _upsert(DownloadTask task) {
    _tasks[task.id] = task;
    _controllers[task.id]?.add(task);
    _notify();
  }

  void _notify() {
    tasksNotifier.value = _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

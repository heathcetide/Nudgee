import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import 'package:nudgee/core/network/api_client.dart';
import 'package:nudgee/core/models/upload_task.dart';

/// Result of a single upload operation.
class UploadResult {
  /// The decoded server response data, if any.
  final dynamic data;

  /// HTTP status code returned by the server.
  final int? statusCode;

  const UploadResult({this.data, this.statusCode});

  /// Whether the upload succeeded (2xx).
  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;
}

/// Centralized file upload service.
///
/// Wraps [ApiClient.upload] with conveniences for single / batch / chunked
/// uploads, MIME detection, progress reporting, cancellation and a simple
/// in-memory upload queue surfaced to the UI via [ValueNotifier].
class UploadService {
  UploadService(this._apiClient, {Uuid? uuidGenerator})
      : _uuid = uuidGenerator ?? const Uuid();

  final ApiClient _apiClient;
  final Uuid _uuid;

  /// Default upload endpoint. Override per-call via [UploadService] methods
  /// is not exposed here — callers may extend this class or use [uploadFile]
  /// with a custom [path] argument to the server route.
  static const String defaultEndpoint = '/upload';

  /// Chunked-upload init / complete endpoints.
  static const String chunkInitEndpoint = '/upload/chunk/init';
  static const String chunkCompleteEndpoint = '/upload/chunk/complete';

  // ── Queue state ──────────────────────────────────────────────────────

  /// All known upload tasks keyed by id.
  final Map<String, UploadTask> _tasks = {};

  /// Active cancel tokens keyed by task id.
  final Map<String, CancelToken> _cancelTokens = {};

  /// Notifier that emits the current list of tasks (newest first).
  final ValueNotifier<List<UploadTask>> tasksNotifier = ValueNotifier(const []);

  /// Read-only access to the current task list.
  List<UploadTask> get tasks => tasksNotifier.value;

  /// Get the status of a task by [id], or `null` if unknown.
  UploadStatus? getUploadStatus(String id) => _tasks[id]?.status;

  /// Get a task by [id].
  UploadTask? getUploadTask(String id) => _tasks[id];

  // ── Single file upload ───────────────────────────────────────────────

  /// Upload a single file at [filePath] to [endpoint].
  ///
  /// [onProgress] receives a fraction in `[0.0, 1.0]`. Pass a [cancelToken]
  /// to support cancellation. The MIME type is auto-detected via the [mime]
  /// package when [mimeType] is not supplied.
  Future<UploadResult> uploadFile(
    String filePath, {
    String endpoint = defaultEndpoint,
    String? fileName,
    String? mimeType,
    Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final detectedMime = mimeType ?? lookupMimeType(filePath) ?? 'application/octet-stream';
    final name = fileName ?? filePath.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: name,
        contentType: DioMediaType.parse(detectedMime),
      ),
    });

    final response = await _apiClient.upload<Map<String, dynamic>>(
      endpoint,
      formData: formData,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total <= 0) return;
        final p = (sent / total).clamp(0.0, 1.0);
        onProgress?.call(p);
      },
    );

    return UploadResult(data: response.data, statusCode: response.statusCode);
  }

  // ── Image upload (optionally compressed) ─────────────────────────────

  /// Upload an image file. [quality] is reserved for future client-side
  /// compression (1-100); currently the file is uploaded as-is with its
  /// detected MIME type.
  Future<UploadResult> uploadImage(
    String filePath, {
    String endpoint = defaultEndpoint,
    int? quality,
    Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // [quality] is accepted for API parity with pickImage; client-side
    // re-encoding will be wired in once a compressor dependency is added.
    final mime = lookupMimeType(filePath) ?? 'image/jpeg';
    return uploadFile(
      filePath,
      endpoint: endpoint,
      mimeType: mime,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  // ── Batch upload ─────────────────────────────────────────────────────

  /// Upload multiple files sequentially.
  ///
  /// [onProgress] reports `(completed, total)` after each file finishes.
  /// Returns the per-file results in input order.
  Future<List<UploadResult>> uploadFiles(
    List<String> paths, {
    String endpoint = defaultEndpoint,
    Function(int completed, int total)? onProgress,
  }) async {
    final results = <UploadResult>[];
    for (var i = 0; i < paths.length; i++) {
      results.add(await uploadFile(paths[i], endpoint: endpoint));
      onProgress?.call(i + 1, paths.length);
    }
    return results;
  }

  // ── Chunked upload ───────────────────────────────────────────────────

  /// Upload a large file in chunks of [chunkSize] bytes.
  ///
  /// A typical chunked flow: (1) init session, (2) upload each chunk,
  /// (3) complete. The exact protocol depends on the server; this method
  /// implements a sensible default that POSTs each chunk to [endpoint]
  /// with an `index` / `total` / `uploadId` form field. Override endpoints
  /// as needed.
  Future<UploadResult> uploadChunked(
    String filePath, {
    String endpoint = defaultEndpoint,
    int chunkSize = 1024 * 1024,
    Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final totalSize = await file.length();
    final totalChunks = (totalSize / chunkSize).ceil();
    final mime = lookupMimeType(filePath) ?? 'application/octet-stream';
    final name = filePath.split(Platform.pathSeparator).last;

    // 1. Init session (best-effort — server may ignore).
    String? uploadId;
    try {
      final initResp = await _apiClient.post<Map<String, dynamic>>(
        chunkInitEndpoint,
        data: {
          'fileName': name,
          'fileSize': totalSize,
          'mimeType': mime,
          'totalChunks': totalChunks,
        },
        cancelToken: cancelToken,
      );
      uploadId = initResp.data?['uploadId'] as String?;
    } catch (e) {
      // Init is optional; continue with a local id if the server rejects.
      uploadId = _uuid.v4();
    }

    // 2. Upload chunks.
    final raf = await file.open();
    try {
      for (var index = 0; index < totalChunks; index++) {
        if (cancelToken?.isCancelled ?? false) {
          throw DioException(
            requestOptions: RequestOptions(path: endpoint),
            type: DioExceptionType.cancel,
          );
        }
        final start = index * chunkSize;
        final end = (index + 1) * chunkSize;
        await raf.setPosition(start);
        final bytes = await raf.read(end > totalSize ? totalSize - start : chunkSize);

        final formData = FormData.fromMap({
          'uploadId': uploadId,
          'index': index,
          'totalChunks': totalChunks,
          'fileName': name,
          'mimeType': mime,
          'chunk': MultipartFile.fromBytes(
            bytes,
            filename: '${name}_part_$index',
            contentType: DioMediaType.parse('application/octet-stream'),
          ),
        });

        await _apiClient.upload<void>(
          endpoint,
          formData: formData,
          cancelToken: cancelToken,
        );

        final p = ((index + 1) / totalChunks).clamp(0.0, 1.0);
        onProgress?.call(p);
      }
    } finally {
      await raf.close();
    }

    // 3. Complete session (best-effort).
    dynamic completeData;
    int? completeStatus;
    try {
      final completeResp = await _apiClient.post<Map<String, dynamic>>(
        chunkCompleteEndpoint,
        data: {
          'uploadId': uploadId,
          'fileName': name,
          'totalChunks': totalChunks,
        },
        cancelToken: cancelToken,
      );
      completeData = completeResp.data;
      completeStatus = completeResp.statusCode;
    } catch (e) {
      // If the server has no complete step, treat the last chunk response as success.
      completeStatus = 200;
    }

    return UploadResult(data: completeData, statusCode: completeStatus);
  }

  // ── Queue management ─────────────────────────────────────────────────

  /// Enqueue a file for upload. Returns the created [UploadTask].
  ///
  /// The task is added to the queue with [UploadStatus.queued] and starts
  /// uploading immediately (concurrency = 1). Use [cancelUpload] to abort.
  UploadTask enqueueUpload(
    String filePath, {
    String endpoint = defaultEndpoint,
    String? fileName,
    String? mimeType,
  }) {
    final id = _uuid.v4();
    final name = fileName ?? filePath.split(Platform.pathSeparator).last;
    final file = File(filePath);
    final size = file.existsSync() ? file.lengthSync() : 0;
    final mime = mimeType ?? lookupMimeType(filePath);

    final task = UploadTask(
      id: id,
      filePath: filePath,
      fileName: name,
      fileSize: size,
      mimeType: mime,
      totalBytes: size,
      createdAt: DateTime.now(),
    );
    _addTask(task);

    // Fire-and-forget the actual upload.
    _runUpload(task, endpoint: endpoint);

    return task;
  }

  /// Cancel an in-flight or queued upload by [id].
  ///
  /// Returns `true` if a cancel was issued, `false` if the task was unknown
  /// or already finished.
  bool cancelUpload(String id) {
    final task = _tasks[id];
    if (task == null || task.isFinished) return false;
    _cancelTokens[id]?.cancel();
    _updateTask(task.copyWith(
      status: UploadStatus.cancelled,
      completedAt: DateTime.now(),
    ));
    return true;
  }

  /// Retry a failed or cancelled upload.
  ///
  /// Returns the updated task, or `null` if the task was unknown or not in
  /// a retryable state.
  UploadTask? retryUpload(String id, {String endpoint = defaultEndpoint}) {
    final task = _tasks[id];
    if (task == null) return null;
    if (task.status != UploadStatus.failed && task.status != UploadStatus.cancelled) {
      return null;
    }
    final reset = task.copyWith(
      status: UploadStatus.queued,
      progress: 0.0,
      uploadedBytes: 0,
      error: null,
      completedAt: null,
    );
    _updateTask(reset);
    _runUpload(reset, endpoint: endpoint);
    return reset;
  }

  /// Remove a finished task from the queue.
  void removeTask(String id) {
    _tasks.remove(id);
    _cancelTokens.remove(id);
    _emit();
  }

  /// Clear all finished tasks from the queue.
  void clearFinished() {
    _tasks.removeWhere((_, t) => t.isFinished);
    _cancelTokens.removeWhere((id, _) => !_tasks.containsKey(id));
    _emit();
  }

  // ── Private ──────────────────────────────────────────────────────────

  Future<void> _runUpload(
    UploadTask task, {
    String endpoint = defaultEndpoint,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    _updateTask(task.copyWith(status: UploadStatus.uploading));

    try {
      final result = await uploadFile(
        task.filePath,
        endpoint: endpoint,
        fileName: task.fileName,
        mimeType: task.mimeType,
        cancelToken: cancelToken,
        onProgress: (p) {
          _updateTask(_tasks[task.id]!.copyWith(
            progress: p,
            uploadedBytes: (p * task.totalBytes).round(),
          ));
        },
      );

      _updateTask(_tasks[task.id]!.copyWith(
        status: result.isSuccess ? UploadStatus.completed : UploadStatus.failed,
        progress: 1.0,
        uploadedBytes: task.totalBytes,
        result: result.data is Map<String, dynamic>
            ? result.data as Map<String, dynamic>
            : null,
        error: result.isSuccess ? null : 'Upload failed (${result.statusCode})',
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      if (cancelToken.isCancelled) {
        // Status already set by cancelUpload.
        return;
      }
      _updateTask(_tasks[task.id]!.copyWith(
        status: UploadStatus.failed,
        error: e.toString(),
        completedAt: DateTime.now(),
      ));
    } finally {
      _cancelTokens.remove(task.id);
    }
  }

  void _addTask(UploadTask task) {
    _tasks[task.id] = task;
    _emit();
  }

  void _updateTask(UploadTask task) {
    _tasks[task.id] = task;
    _emit();
  }

  void _emit() {
    // Newest first.
    tasksNotifier.value = _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

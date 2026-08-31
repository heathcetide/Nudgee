import 'package:equatable/equatable.dart';

/// Status of an [UploadTask] in the upload lifecycle.
enum UploadStatus {
  /// Waiting in the queue to be processed.
  queued,

  /// Currently uploading bytes to the server.
  uploading,

  /// Manually paused by the user.
  paused,

  /// Successfully completed.
  completed,

  /// Failed due to a network or server error.
  failed,

  /// Cancelled by the user or system.
  cancelled,
}

/// Represents a single file upload operation tracked by [UploadService].
///
/// Immutable value object — use [copyWith] to produce updated instances
/// as the upload progresses. Registered in the upload queue and surfaced
/// to the UI via [LingUploadProgress].
class UploadTask extends Equatable {
  /// Unique identifier (typically a UUID).
  final String id;

  /// Absolute path of the local file to upload.
  final String filePath;

  /// Display name of the file.
  final String fileName;

  /// Total size of the file in bytes.
  final int fileSize;

  /// Detected MIME type of the file (e.g. `image/jpeg`).
  final String? mimeType;

  /// Current lifecycle status.
  final UploadStatus status;

  /// Upload progress as a fraction in `[0.0, 1.0]`.
  final double progress;

  /// Number of bytes already uploaded.
  final int uploadedBytes;

  /// Total bytes to upload (equals [fileSize] in most cases).
  final int totalBytes;

  /// The decoded server response on success, if any.
  final Map<String, dynamic>? result;

  /// Error message when [status] is [UploadStatus.failed].
  final String? error;

  /// When the task was created (queued).
  final DateTime createdAt;

  /// When the task finished (completed / failed / cancelled).
  final DateTime? completedAt;

  const UploadTask({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
    this.status = UploadStatus.queued,
    this.progress = 0.0,
    this.uploadedBytes = 0,
    required this.totalBytes,
    this.result,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  /// Whether the task is in a terminal state.
  bool get isFinished =>
      status == UploadStatus.completed ||
      status == UploadStatus.failed ||
      status == UploadStatus.cancelled;

  /// Whether the task is actively transferring bytes.
  bool get isUploading => status == UploadStatus.uploading;

  /// Human-readable progress percentage (e.g. `42`).
  int get percent => (progress * 100).round().clamp(0, 100);

  /// Produce a new [UploadTask] with selective field overrides.
  UploadTask copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    UploadStatus? status,
    double? progress,
    int? uploadedBytes,
    int? totalBytes,
    Map<String, dynamic>? result,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
  }) =>
      UploadTask(
        id: id ?? this.id,
        filePath: filePath ?? this.filePath,
        fileName: fileName ?? this.fileName,
        fileSize: fileSize ?? this.fileSize,
        mimeType: mimeType ?? this.mimeType,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        uploadedBytes: uploadedBytes ?? this.uploadedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        result: result ?? this.result,
        error: error ?? this.error,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt ?? this.completedAt,
      );

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'status': status.name,
        'progress': progress,
        'uploadedBytes': uploadedBytes,
        'totalBytes': totalBytes,
        if (result != null) 'result': result,
        if (error != null) 'error': error,
        'createdAt': createdAt.toIso8601String(),
        if (completedAt != null)
          'completedAt': completedAt!.toIso8601String(),
      };

  /// Deserialize from a JSON map.
  factory UploadTask.fromJson(Map<String, dynamic> json) => UploadTask(
        id: json['id'] as String? ?? '',
        filePath: json['filePath'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
        mimeType: json['mimeType'] as String?,
        status: _parseStatus(json['status'] as String?),
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        uploadedBytes: (json['uploadedBytes'] as num?)?.toInt() ?? 0,
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        result: json['result'] is Map<String, dynamic>
            ? json['result'] as Map<String, dynamic>
            : null,
        error: json['error'] as String?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
      );

  static UploadStatus _parseStatus(String? value) {
    switch (value) {
      case 'queued':
        return UploadStatus.queued;
      case 'uploading':
        return UploadStatus.uploading;
      case 'paused':
        return UploadStatus.paused;
      case 'completed':
        return UploadStatus.completed;
      case 'failed':
        return UploadStatus.failed;
      case 'cancelled':
        return UploadStatus.cancelled;
      default:
        return UploadStatus.queued;
    }
  }

  @override
  List<Object?> get props => [
        id,
        filePath,
        fileName,
        fileSize,
        mimeType,
        status,
        progress,
        uploadedBytes,
        totalBytes,
        result,
        error,
        createdAt,
        completedAt,
      ];
}

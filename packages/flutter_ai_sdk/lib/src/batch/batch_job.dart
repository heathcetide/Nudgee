import 'package:equatable/equatable.dart';

/// Status of a batch job, unified across providers.
enum BatchStatus {
  /// The input is being validated before processing starts.
  validating,

  /// Requests are being processed.
  inProgress,

  /// The job finished. Individual requests may still have failed —
  /// check each `BatchResult` for its own outcome.
  completed,

  /// The job itself failed (e.g. invalid input file).
  failed,

  /// The job didn't finish within the provider's completion window.
  expired,

  /// The job was cancelled.
  cancelled,
}

/// Whether a [BatchStatus] is terminal (won't transition further).
extension BatchStatusX on BatchStatus {
  /// Whether the job has reached a terminal state — [BatchJob.isTerminal].
  bool get isTerminal => switch (this) {
        BatchStatus.completed ||
        BatchStatus.failed ||
        BatchStatus.expired ||
        BatchStatus.cancelled =>
          true,
        BatchStatus.validating || BatchStatus.inProgress => false,
      };
}

/// The state of a submitted batch job.
class BatchJob with Equatable {
  /// Creates a [BatchJob].
  const BatchJob({
    required this.id,
    required this.status,
    this.totalRequests,
    this.completedRequests,
    this.failedRequests,
    this.metadata,
  });

  /// Provider-assigned batch job identifier.
  final String id;

  /// Current status of the job.
  final BatchStatus status;

  /// Total number of requests in the batch, if reported.
  final int? totalRequests;

  /// Number of requests completed so far, if reported.
  final int? completedRequests;

  /// Number of requests that failed, if reported.
  final int? failedRequests;

  /// Additional provider-specific data (e.g. the raw response), used
  /// internally by providers that need extra state between calls.
  final Map<String, dynamic>? metadata;

  /// Whether this job has reached a terminal state — see
  /// [BatchStatusX.isTerminal].
  bool get isTerminal => status.isTerminal;

  @override
  List<Object?> get props => [
        id,
        status,
        totalRequests,
        completedRequests,
        failedRequests,
      ];
}

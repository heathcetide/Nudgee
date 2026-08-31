import 'package:flutter_ai_sdk/src/batch/batch_job.dart';
import 'package:flutter_ai_sdk/src/batch/batch_request.dart';
import 'package:flutter_ai_sdk/src/batch/batch_result.dart';

/// Contract for providers that support asynchronous batch processing,
/// typically at a reduced cost compared to synchronous requests.
///
/// Deliberately separate from `BaseProvider` — only Anthropic and OpenAI
/// currently expose a batch API; Google AI and Ollama don't.
abstract interface class BatchProvider {
  /// Submits [requests] as a new batch job.
  Future<BatchJob> submitBatch(List<BatchRequest> requests);

  /// Fetches the current status of the batch job [batchId].
  Future<BatchJob> getBatchStatus(String batchId);

  /// Fetches the results of batch job [batchId].
  ///
  /// Only meaningful once the job is terminal (see
  /// `BatchStatusX.isTerminal`) — call this after polling completes.
  /// Results are not guaranteed to come back in submission order; match
  /// them to requests via `BatchResult.customId`.
  Future<List<BatchResult>> getBatchResults(String batchId);
}

import 'package:flutter_ai_sdk/src/batch/batch_job.dart';
import 'package:flutter_ai_sdk/src/batch/batch_provider.dart';

/// Polls [provider] for the status of [batchId] until it reaches a
/// terminal state, yielding every intermediate [BatchJob] (including the
/// final one).
///
/// Uses exponential backoff between polls, starting at [initialInterval]
/// and capped at [maxInterval], to avoid hammering the provider during
/// jobs that can take hours to complete.
Stream<BatchJob> pollBatchJob(
  BatchProvider provider,
  String batchId, {
  Duration initialInterval = const Duration(seconds: 5),
  Duration maxInterval = const Duration(seconds: 60),
}) async* {
  var interval = initialInterval;
  while (true) {
    final job = await provider.getBatchStatus(batchId);
    yield job;
    if (job.isTerminal) return;

    await Future<void>.delayed(interval);
    final doubled = interval * 2;
    interval = doubled > maxInterval ? maxInterval : doubled;
  }
}

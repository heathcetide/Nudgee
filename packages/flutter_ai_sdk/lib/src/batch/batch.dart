/// Batch processing support for the Flutter AI SDK.
///
/// This module exports the batch request/job/result models, the
/// `BatchProvider` contract implemented by providers that expose a batch
/// API (Anthropic, OpenAI), and a polling helper.
library;

export 'batch_job.dart';
export 'batch_polling.dart';
export 'batch_provider.dart';
export 'batch_request.dart';
export 'batch_result.dart';

import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/batch/batch_request.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';

/// The outcome of a single request within a batch job.
///
/// Exactly one of [response] or [error] is set. Match results back to
/// requests via [customId] — batch results are not guaranteed to come
/// back in submission order.
class BatchResult with Equatable {
  /// Creates a [BatchResult].
  const BatchResult({
    required this.customId,
    this.response,
    this.error,
  });

  /// The [BatchRequest.customId] this result corresponds to.
  final String customId;

  /// The response, if this request succeeded.
  final AIResponse? response;

  /// The error details, if this request failed.
  final Object? error;

  /// Whether this request succeeded.
  bool get isSuccess => response != null;

  @override
  List<Object?> get props => [customId, response, error];
}

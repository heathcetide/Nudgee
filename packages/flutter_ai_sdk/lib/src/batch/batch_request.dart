import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';

/// A single request within a batch job.
///
/// [customId] is caller-supplied and used to match `BatchResult`s back to
/// requests — batch results are not guaranteed to come back in submission
/// order.
///
/// Example:
/// ```dart
/// final request = BatchRequest(
///   customId: 'summary-1',
///   messages: [Message.user('Summarize: ...')],
///   config: AIConfig(apiKey: 'sk-...', model: 'gpt-5.5'),
/// );
/// ```
class BatchRequest with Equatable {
  /// Creates a [BatchRequest].
  const BatchRequest({
    required this.customId,
    required this.messages,
    required this.config,
  });

  /// Caller-supplied identifier, echoed back on the matching `BatchResult`.
  final String customId;

  /// The conversation to send.
  final List<Message> messages;

  /// Per-request configuration (model, sampling parameters...).
  final AIConfig config;

  @override
  List<Object?> get props => [customId, messages, config];
}

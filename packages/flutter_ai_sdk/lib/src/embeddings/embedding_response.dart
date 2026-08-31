import 'package:equatable/equatable.dart';

/// The result of an embedding request.
///
/// [embeddings] carries one vector per input, in the same order as the
/// request's input list.
class EmbeddingResponse with Equatable {
  /// Creates an [EmbeddingResponse].
  const EmbeddingResponse({
    required this.embeddings,
    this.model,
    this.promptTokens,
  });

  /// One embedding vector per input, in request order.
  final List<List<double>> embeddings;

  /// The model that generated the embeddings, if reported by the provider.
  final String? model;

  /// Tokens consumed by the request, if reported by the provider.
  final int? promptTokens;

  @override
  List<Object?> get props => [embeddings, model, promptTokens];
}

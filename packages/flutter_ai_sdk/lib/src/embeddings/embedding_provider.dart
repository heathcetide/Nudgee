import 'package:flutter_ai_sdk/src/embeddings/embedding_request.dart';
import 'package:flutter_ai_sdk/src/embeddings/embedding_response.dart';

/// Contract for providers that can generate embedding vectors.
///
/// Deliberately separate from `BaseProvider` — not every chat provider
/// exposes an embeddings API (Anthropic doesn't have one, for instance).
/// Provider classes that do support embeddings implement this interface
/// in addition to `BaseProvider`.
abstract interface class EmbeddingProvider {
  /// Generates embedding vectors for [EmbeddingRequest.input].
  Future<EmbeddingResponse> embed(EmbeddingRequest request);
}

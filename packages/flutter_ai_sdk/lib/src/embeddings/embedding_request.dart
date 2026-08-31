import 'package:equatable/equatable.dart';

/// A request to generate embedding vectors for one or more text inputs.
///
/// Example:
/// ```dart
/// final request = EmbeddingRequest(input: ['Hello, world!']);
/// ```
class EmbeddingRequest with Equatable {
  /// Creates an [EmbeddingRequest].
  const EmbeddingRequest({required this.input, this.model});

  /// The text(s) to embed.
  final List<String> input;

  /// The embedding model to use, falling back to the provider's default.
  final String? model;

  @override
  List<Object?> get props => [input, model];
}

import 'dart:math';

/// Cosine similarity between two equal-length embedding vectors.
///
/// Returns a value in `[-1, 1]` — `1` means identical direction, `0` means
/// orthogonal (unrelated), `-1` means opposite direction. This is the
/// standard similarity metric for comparing embedding vectors in RAG /
/// semantic search use cases.
///
/// Throws an [ArgumentError] if [a] and [b] have different lengths, or if
/// either is a zero vector (undefined similarity).
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Vectors must have the same length');
  }

  var dotProduct = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  if (normA == 0 || normB == 0) {
    throw ArgumentError('Vectors must not be zero vectors');
  }

  return dotProduct / (sqrt(normA) * sqrt(normB));
}

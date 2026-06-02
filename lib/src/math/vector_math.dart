import 'dart:math' as math;

/// Vector math helpers used by the RAG engine.
///
/// All functions operate on `List<double>` vectors. For performance, callers
/// that work with normalised vectors can use [dotProduct] directly, which
/// equals the cosine similarity when both inputs are unit vectors.
class VectorMath {
  const VectorMath._();

  /// Returns the dot product of [a] and [b].
  ///
  /// Throws an [ArgumentError] if the vectors have different lengths.
  static double dotProduct(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vectors must have equal length: '
          '${a.length} != ${b.length}');
    }
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  /// Returns the Euclidean (L2) norm of [v].
  static double norm(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    return math.sqrt(sum);
  }

  /// Returns a new vector that is [v] scaled to unit length.
  ///
  /// If [v] is the zero vector, a copy of it is returned unchanged.
  static List<double> normalize(List<double> v) {
    final n = norm(v);
    if (n == 0) return List<double>.of(v);
    return [for (final x in v) x / n];
  }

  /// Returns the cosine similarity of [a] and [b], in the range `[-1, 1]`.
  ///
  /// Returns `0` if either vector is the zero vector.
  static double cosineSimilarity(List<double> a, List<double> b) {
    final denom = norm(a) * norm(b);
    if (denom == 0) return 0;
    return dotProduct(a, b) / denom;
  }
}

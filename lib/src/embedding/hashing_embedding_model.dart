import 'dart:math' as math;

import 'embedding_model.dart';

/// A zero-dependency, fully offline [EmbeddingModel] based on the hashing trick
/// (feature hashing).
///
/// It hashes each word and its character tri-grams into a fixed-size vector
/// using signed hashing, then L2-normalises the result. It is tiny,
/// deterministic, and needs no model download, so a RAG pipeline works the
/// moment it is installed.
///
/// Trade-off: it captures *lexical* (word-overlap) similarity, not deep
/// *semantic* similarity. For semantic retrieval, implement [EmbeddingModel]
/// with a sentence-transformer (for example all-MiniLM-L6-v2) and pass it to
/// the engine instead — nothing else changes.
class HashingEmbeddingModel extends EmbeddingModel {
  /// Creates a hashing embedder producing vectors of length [dimensions].
  const HashingEmbeddingModel({this.dimensions = 256})
      : assert(dimensions > 0, 'dimensions must be positive');

  @override
  final int dimensions;

  @override
  Future<List<double>> embed(String text) async {
    final vec = List<double>.filled(dimensions, 0);
    for (final token in _tokenize(text)) {
      _add(vec, token, 1);
      for (final tri in _charNGrams(token, 3)) {
        _add(vec, tri, 0.5);
      }
    }
    return _l2normalize(vec);
  }

  List<String> _tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  Iterable<String> _charNGrams(String s, int n) sync* {
    if (s.length < n) {
      yield s;
      return;
    }
    for (var i = 0; i <= s.length - n; i++) {
      yield s.substring(i, i + n);
    }
  }

  void _add(List<double> vec, String feature, double weight) {
    final h = feature.hashCode;
    final idx = (h & 0x7fffffff) % dimensions;
    final sign = (h & 1) == 0 ? 1.0 : -1.0;
    vec[idx] += sign * weight;
  }

  List<double> _l2normalize(List<double> v) {
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return v;
    for (var i = 0; i < v.length; i++) {
      v[i] /= norm;
    }
    return v;
  }
}

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
/// Hashing uses 32-bit FNV-1a, so vectors are identical on every platform
/// (VM, AOT, web) and across Dart SDK versions — an index persisted with
/// `InMemoryVectorStore.toJson` stays valid after an app update. Tokenisation
/// is Unicode-aware, so non-English text (accented Latin, Devanagari, Tamil,
/// CJK, ...) is embedded too.
///
/// Trade-off: it captures *lexical* (word-overlap) similarity, not deep
/// *semantic* similarity. For semantic retrieval, implement [EmbeddingModel]
/// with a sentence-transformer (for example all-MiniLM-L6-v2) and pass it to
/// the engine instead — nothing else changes.
class HashingEmbeddingModel extends EmbeddingModel {
  /// Creates a hashing embedder producing vectors of length [dimensions].
  ///
  /// [ngramSize] is the character n-gram length mixed in alongside whole
  /// words (set it to `0` to hash whole words only) and [ngramWeight] is how
  /// much each n-gram counts relative to a word.
  const HashingEmbeddingModel({
    this.dimensions = 256,
    this.ngramSize = 3,
    this.ngramWeight = 0.5,
  })  : assert(dimensions > 0, 'dimensions must be positive'),
        assert(ngramSize >= 0, 'ngramSize must not be negative');

  @override
  final int dimensions;

  /// Character n-gram length; `0` disables n-grams.
  final int ngramSize;

  /// Weight of each character n-gram relative to a whole word.
  final double ngramWeight;

  static final RegExp _separators =
      RegExp(r'[^\p{L}\p{N}\p{M}]+', unicode: true);

  @override
  Future<List<double>> embed(String text) async => embedSync(text);

  /// Synchronous version of [embed], handy in isolates and tight loops.
  List<double> embedSync(String text) {
    final vec = List<double>.filled(dimensions, 0);
    for (final token in tokenize(text)) {
      _add(vec, token, 1);
      if (ngramSize > 0) {
        for (final gram in _charNGrams(token, ngramSize)) {
          _add(vec, '#$gram', ngramWeight);
        }
      }
    }
    return _l2normalize(vec);
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async =>
      [for (final t in texts) embedSync(t)];

  /// Splits [text] into lower-cased word tokens on any non-letter, non-digit
  /// character.
  static List<String> tokenize(String text) =>
      text.toLowerCase().split(_separators).where((t) => t.isNotEmpty).toList();

  Iterable<String> _charNGrams(String s, int n) sync* {
    final runes = s.runes.toList();
    if (runes.length <= n) return;
    for (var i = 0; i <= runes.length - n; i++) {
      yield String.fromCharCodes(runes, i, i + n);
    }
  }

  void _add(List<double> vec, String feature, double weight) {
    final h = fnv1a32(feature);
    final idx = (h >> 1) % dimensions;
    final sign = (h & 1) == 0 ? 1.0 : -1.0;
    vec[idx] += sign * weight;
  }

  /// 32-bit FNV-1a hash of the UTF-16 code units of [s].
  ///
  /// Stable across platforms and SDK versions, unlike `String.hashCode`.
  static int fnv1a32(String s) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      // Multiply by the FNV prime 16777619 (2^24 + 403) modulo 2^32, split so
      // intermediate values stay exact on the web.
      hash = (hash * 403 + ((hash << 24) & 0xffffffff)) & 0xffffffff;
    }
    return hash;
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

import '../math/vector_math.dart';
import '../models/rag_document.dart';
import 'vector_store.dart';

/// An in-memory [VectorStore] that ranks documents by cosine similarity using a
/// brute-force scan.
///
/// Brute force is simple and fast for the personal-scale corpora typical of
/// on-device apps (up to tens of thousands of chunks). Vector norms are cached
/// on insert, so each search costs one dot product per document. For much
/// larger corpora, implement [VectorStore] with an approximate-nearest-neighbour
/// index.
///
/// The store can be serialised with [toJson] and restored with
/// [InMemoryVectorStore.fromJson], so callers can persist the index however
/// they like (a file, shared preferences, a database column).
class InMemoryVectorStore implements VectorStore {
  /// Creates an empty store.
  InMemoryVectorStore();

  /// Restores a store from a [json] map produced by [toJson].
  factory InMemoryVectorStore.fromJson(Map<String, Object?> json) {
    final store = InMemoryVectorStore();
    final docs = (json['documents'] as List<Object?>?) ?? const [];
    for (final e in docs) {
      store._insert(
        RagDocument.fromJson((e! as Map<Object?, Object?>).cast<String, Object?>()),
      );
    }
    return store;
  }

  final List<RagDocument> _docs = [];
  final List<double> _norms = [];

  /// An unmodifiable view of every stored document, in insertion order.
  List<RagDocument> get documents => List.unmodifiable(_docs);

  void _insert(RagDocument d) {
    final embedding = d.embedding;
    if (embedding == null) {
      throw ArgumentError('Document "${d.id ?? d.text}" has no embedding.');
    }
    _docs.add(d);
    _norms.add(VectorMath.norm(embedding));
  }

  @override
  Future<void> add(List<RagDocument> documents) async {
    for (final d in documents) {
      if (d.embedding == null) {
        throw ArgumentError('Document "${d.id ?? d.text}" has no embedding.');
      }
    }
    documents.forEach(_insert);
  }

  @override
  Future<List<ScoredDocument>> search(
    List<double> queryEmbedding, {
    int topK = 4,
    DocumentFilter? where,
  }) async {
    if (topK <= 0 || _docs.isEmpty) return const [];
    final queryNorm = VectorMath.norm(queryEmbedding);
    final scored = <ScoredDocument>[];
    for (var i = 0; i < _docs.length; i++) {
      final d = _docs[i];
      if (where != null && !where(d)) continue;
      final denom = queryNorm * _norms[i];
      final score = denom == 0
          ? 0.0
          : VectorMath.dotProduct(queryEmbedding, d.embedding!) / denom;
      scored.add(ScoredDocument(document: d, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.length <= topK
        ? scored
        : scored.sublist(0, topK);
  }

  @override
  Future<int> removeWhere(DocumentFilter test) async {
    var removed = 0;
    for (var i = _docs.length - 1; i >= 0; i--) {
      if (test(_docs[i])) {
        _docs.removeAt(i);
        _norms.removeAt(i);
        removed++;
      }
    }
    return removed;
  }

  @override
  Future<void> clear() async {
    _docs.clear();
    _norms.clear();
  }

  @override
  Future<int> get length async => _docs.length;

  /// Serialises every stored document to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'documents': [for (final d in _docs) d.toJson()],
      };
}

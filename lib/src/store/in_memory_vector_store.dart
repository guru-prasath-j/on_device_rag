import '../math/vector_math.dart';
import '../models/rag_document.dart';
import 'vector_store.dart';

/// An in-memory [VectorStore] that ranks documents by cosine similarity using a
/// brute-force scan.
///
/// Brute force is simple and fast for the personal-scale corpora typical of
/// on-device apps (up to a few thousand chunks). For much larger corpora,
/// implement [VectorStore] with an approximate-nearest-neighbour index.
///
/// The store can be serialised with [toJson] and restored with
/// [InMemoryVectorStore.fromJson], so callers can persist the index however
/// they like (a file, shared preferences, a database column).
class InMemoryVectorStore implements VectorStore {
  /// Creates an empty store.
  InMemoryVectorStore();

  final List<RagDocument> _docs = [];

  @override
  Future<void> add(List<RagDocument> documents) async {
    for (final d in documents) {
      if (d.embedding == null) {
        throw ArgumentError('Document "${d.id ?? d.text}" has no embedding.');
      }
    }
    _docs.addAll(documents);
  }

  @override
  Future<List<ScoredDocument>> search(
    List<double> queryEmbedding, {
    int topK = 4,
  }) async {
    final scored = <ScoredDocument>[
      for (final d in _docs)
        ScoredDocument(
          document: d,
          score: VectorMath.cosineSimilarity(queryEmbedding, d.embedding!),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList(growable: false);
  }

  @override
  Future<void> clear() async => _docs.clear();

  @override
  Future<int> get length async => _docs.length;

  /// Serialises every stored document to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'documents': [for (final d in _docs) d.toJson()],
      };

  /// Restores a store from a [json] map produced by [toJson].
  factory InMemoryVectorStore.fromJson(Map<String, Object?> json) {
    final store = InMemoryVectorStore();
    final docs = (json['documents'] as List?) ?? const [];
    store._docs.addAll(
      docs.map((e) => RagDocument.fromJson((e as Map).cast<String, Object?>())),
    );
    return store;
  }
}

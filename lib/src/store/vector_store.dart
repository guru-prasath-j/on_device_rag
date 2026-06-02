import '../models/rag_document.dart';

/// A store of embedded [RagDocument]s that supports similarity search.
///
/// Implement this to back the index with any storage engine (SQLite, a file,
/// an HTTP service). The bundled [InMemoryVectorStore] keeps everything in
/// memory and can be serialised to and from JSON.
abstract interface class VectorStore {
  /// Adds [documents] (each of which must carry an embedding) to the store.
  Future<void> add(List<RagDocument> documents);

  /// Returns the [topK] documents most similar to [queryEmbedding], ordered by
  /// descending score.
  Future<List<ScoredDocument>> search(
    List<double> queryEmbedding, {
    int topK = 4,
  });

  /// Removes all documents from the store.
  Future<void> clear();

  /// The number of documents currently stored.
  Future<int> get length;
}

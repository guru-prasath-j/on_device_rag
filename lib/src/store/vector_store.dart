import '../models/rag_document.dart';

/// A predicate used to restrict searches or removals to some documents, for
/// example `(doc) => doc.metadata['source'] == 'manual.pdf'`.
typedef DocumentFilter = bool Function(RagDocument document);

/// A store of embedded [RagDocument]s that supports similarity search.
///
/// Implement this to back the index with any storage engine (SQLite, a file,
/// an HTTP service). The bundled `InMemoryVectorStore` keeps everything in
/// memory and can be serialised to and from JSON.
abstract interface class VectorStore {
  /// Adds [documents] (each of which must carry an embedding) to the store.
  Future<void> add(List<RagDocument> documents);

  /// Returns the [topK] documents most similar to [queryEmbedding], ordered by
  /// descending score.
  ///
  /// When [where] is given, only documents it accepts are considered.
  Future<List<ScoredDocument>> search(
    List<double> queryEmbedding, {
    int topK = 4,
    DocumentFilter? where,
  });

  /// Removes every document [test] accepts and returns how many were removed.
  Future<int> removeWhere(DocumentFilter test);

  /// Removes all documents from the store.
  Future<void> clear();

  /// The number of documents currently stored.
  Future<int> get length;
}

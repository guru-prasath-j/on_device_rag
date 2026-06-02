/// A unit of knowledge stored in the RAG index.
///
/// A [RagDocument] is typically one chunk of a larger source document. It holds
/// the chunk [text], its [embedding] vector, and optional [metadata] (for
/// example the source file name or page number) plus an [id].
class RagDocument {
  /// Creates a document with the given [text] and optional [embedding].
  RagDocument({
    required this.text,
    this.id,
    this.embedding,
    Map<String, Object?>? metadata,
  }) : metadata = metadata ?? const {};

  /// A stable identifier for this document, if any.
  final String? id;

  /// The raw chunk text.
  final String text;

  /// The embedding vector for [text], or `null` if not yet embedded.
  final List<double>? embedding;

  /// Arbitrary, JSON-serialisable metadata attached to this document.
  final Map<String, Object?> metadata;

  /// Returns a copy of this document with the provided fields replaced.
  RagDocument copyWith({
    String? id,
    String? text,
    List<double>? embedding,
    Map<String, Object?>? metadata,
  }) {
    return RagDocument(
      id: id ?? this.id,
      text: text ?? this.text,
      embedding: embedding ?? this.embedding,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Serialises this document to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'id': id,
        'text': text,
        'embedding': embedding,
        'metadata': metadata,
      };

  /// Reconstructs a document from a [json] map produced by [toJson].
  factory RagDocument.fromJson(Map<String, Object?> json) {
    final rawEmbedding = json['embedding'] as List<Object?>?;
    return RagDocument(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      embedding:
          rawEmbedding?.map((e) => (e as num).toDouble()).toList(growable: false),
      metadata: (json['metadata'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }
}

/// A [RagDocument] paired with its similarity [score] from a search.
class ScoredDocument {
  /// Creates a scored result.
  const ScoredDocument({required this.document, required this.score});

  /// The matched document.
  final RagDocument document;

  /// The similarity score (higher is more similar).
  final double score;
}

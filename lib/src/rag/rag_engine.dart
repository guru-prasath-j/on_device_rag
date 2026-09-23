import '../chunking/text_chunker.dart';
import '../embedding/embedding_model.dart';
import '../embedding/hashing_embedding_model.dart';
import '../llm/language_model.dart';
import '../math/vector_math.dart';
import '../models/rag_document.dart';
import '../store/in_memory_vector_store.dart';
import '../store/vector_store.dart';
import 'prompt_builder.dart';
import 'rag_result.dart';

/// Orchestrates a full retrieval-augmented-generation pipeline on the device.
///
/// The engine wires together four pluggable parts:
///
/// 1. a [TextChunker] that breaks source text into retrieval-sized pieces,
/// 2. an [EmbeddingModel] that turns each piece (and later each question) into
///    a vector,
/// 3. a [VectorStore] that indexes those vectors and answers similarity
///    searches,
/// 4. an optional [LanguageModel] that writes the final grounded answer.
///
/// ```dart
/// final engine = RagEngine(languageModel: myModel);
/// await engine.addDocument(id: 'manual', text: manualText);
/// final answer = await engine.query('How do I reset the device?');
/// print(answer.answer);
/// ```
///
/// If no [LanguageModel] is supplied you can still call [retrieve] to get the
/// relevant context — for example to feed it to a model you drive yourself.
class RagEngine {
  /// Creates an engine.
  ///
  /// Every part is optional: [embeddingModel] defaults to
  /// [HashingEmbeddingModel], [vectorStore] to [InMemoryVectorStore], and
  /// [chunker] and [promptBuilder] to their defaults. Without a
  /// [languageModel], [ask], [query] and [queryStream] throw and only
  /// [retrieve] is available. [topK] is the default number of chunks
  /// retrieved per question.
  RagEngine({
    EmbeddingModel? embeddingModel,
    VectorStore? vectorStore,
    this.languageModel,
    TextChunker? chunker,
    PromptBuilder? promptBuilder,
    this.topK = 4,
  })  : assert(topK > 0, 'topK must be positive'),
        embeddingModel = embeddingModel ?? const HashingEmbeddingModel(),
        vectorStore = vectorStore ?? InMemoryVectorStore(),
        chunker = chunker ?? const TextChunker(),
        promptBuilder = promptBuilder ?? const PromptBuilder();

  /// Metadata key under which [addDocument] records the document id.
  static const String documentIdKey = 'documentId';

  /// Metadata key under which the chunk's position in its source is stored.
  static const String chunkIndexKey = 'chunkIndex';

  /// Embeds text and questions.
  final EmbeddingModel embeddingModel;

  /// Stores embedded chunks and serves similarity search.
  final VectorStore vectorStore;

  /// Generates the final answer. May be `null`.
  final LanguageModel? languageModel;

  /// Splits source text into chunks before embedding.
  final TextChunker chunker;

  /// Builds the grounded prompt sent to [languageModel].
  final PromptBuilder promptBuilder;

  /// Default number of chunks to retrieve per question.
  final int topK;

  /// Chunks [text], embeds every chunk and adds them to the [vectorStore].
  ///
  /// Optional [metadata] is attached to each chunk produced from this call (for
  /// example `{'source': 'manual.txt'}`) along with its [chunkIndexKey], and
  /// [idPrefix] seeds per-chunk ids. Returns the documents that were indexed.
  Future<List<RagDocument>> index(
    String text, {
    Map<String, Object?>? metadata,
    String? idPrefix,
  }) async {
    final chunks = chunker.chunk(text);
    if (chunks.isEmpty) return const [];
    final embeddings = await embeddingModel.embedBatch(chunks);
    final docs = <RagDocument>[
      for (var i = 0; i < chunks.length; i++)
        RagDocument(
          id: idPrefix == null ? null : '$idPrefix-$i',
          text: chunks[i],
          embedding: embeddings[i],
          metadata: {...?metadata, chunkIndexKey: i},
        ),
    ];
    await vectorStore.add(docs);
    return docs;
  }

  /// Indexes a named document, replacing any earlier version with the same
  /// [id].
  ///
  /// Chunks carry `metadata[documentIdKey] == id`, so they can be filtered
  /// with `where` in [retrieve] or removed with [removeDocument].
  Future<List<RagDocument>> addDocument({
    required String id,
    required String text,
    Map<String, Object?>? metadata,
  }) async {
    await removeDocument(id);
    return index(
      text,
      metadata: {...?metadata, documentIdKey: id},
      idPrefix: id,
    );
  }

  /// Removes every chunk added by [addDocument] with this [id]. Returns the
  /// number of chunks removed.
  Future<int> removeDocument(String id) =>
      vectorStore.removeWhere((d) => d.metadata[documentIdKey] == id);

  /// Removes everything from the index.
  Future<void> clear() => vectorStore.clear();

  /// Embeds [question] and returns the most similar indexed chunks with their
  /// similarity scores.
  ///
  /// * [topK] defaults to the engine's [topK].
  /// * [minScore] drops chunks less similar than this (cosine, `-1..1`).
  /// * [where] restricts the search, e.g. to one document or source.
  /// * [diversity] (`0..1`) re-ranks with Maximal Marginal Relevance so
  ///   near-duplicate chunks don't crowd out other useful context; `0` (the
  ///   default) ranks purely by similarity.
  Future<List<ScoredDocument>> retrieveScored(
    String question, {
    int? topK,
    double? minScore,
    DocumentFilter? where,
    double diversity = 0,
  }) async {
    if (diversity < 0 || diversity > 1) {
      throw ArgumentError.value(diversity, 'diversity', 'must be in [0, 1]');
    }
    final k = topK ?? this.topK;
    final queryVec = await embeddingModel.embed(question);
    final fetch = diversity > 0 ? k * 4 : k;
    var scored = await vectorStore.search(queryVec, topK: fetch, where: where);
    if (minScore != null) {
      scored = [
        for (final s in scored)
          if (s.score >= minScore) s,
      ];
    }
    if (diversity > 0 && scored.length > 1) {
      final order = VectorMath.maximalMarginalRelevance(
        queryVec,
        [for (final s in scored) s.document.embedding!],
        k: k,
        lambda: 1 - diversity,
      );
      return [for (final i in order) scored[i]];
    }
    return scored.length <= k ? scored : scored.sublist(0, k);
  }

  /// Embeds [question] and returns the most similar indexed documents.
  ///
  /// See [retrieveScored] for the parameters.
  Future<List<RagDocument>> retrieve(
    String question, {
    int? topK,
    double? minScore,
    DocumentFilter? where,
    double diversity = 0,
  }) async {
    final scored = await retrieveScored(
      question,
      topK: topK,
      minScore: minScore,
      where: where,
      diversity: diversity,
    );
    return scored.map((s) => s.document).toList(growable: false);
  }

  /// Answers [question] by retrieving context and generating a grounded reply.
  ///
  /// Retrieves the best chunks (see [retrieveScored] for the parameters),
  /// builds a grounded prompt with [promptBuilder] and streams the answer from
  /// [languageModel]. The returned [RagResult] carries both the streamed answer
  /// and the [RagResult.sources] used. Throws a [StateError] if no
  /// [languageModel] was provided.
  Future<RagResult> ask(
    String question, {
    int? topK,
    double? minScore,
    DocumentFilter? where,
    double diversity = 0,
  }) async {
    final model = _requireModel('ask');
    final scored = await retrieveScored(
      question,
      topK: topK,
      minScore: minScore,
      where: where,
      diversity: diversity,
    );
    final sources = [for (final s in scored) s.document];
    final prompt = promptBuilder.build(question, sources);
    return RagResult(
      answer: model.generate(prompt),
      sources: sources,
      prompt: prompt,
      scores: [for (final s in scored) s.score],
    );
  }

  /// Like [ask], but waits for the whole answer and returns it as text.
  Future<RagAnswer> query(
    String question, {
    int? topK,
    double? minScore,
    DocumentFilter? where,
    double diversity = 0,
  }) async {
    final result = await ask(
      question,
      topK: topK,
      minScore: minScore,
      where: where,
      diversity: diversity,
    );
    return RagAnswer(
      answer: await result.answer.join(),
      sources: result.sources,
      prompt: result.prompt!,
      scores: result.scores,
    );
  }

  /// Like [ask], but returns only the answer tokens as they are generated —
  /// convenient for chat UIs.
  Stream<String> queryStream(
    String question, {
    int? topK,
    double? minScore,
    DocumentFilter? where,
    double diversity = 0,
  }) async* {
    final result = await ask(
      question,
      topK: topK,
      minScore: minScore,
      where: where,
      diversity: diversity,
    );
    yield* result.answer;
  }

  LanguageModel _requireModel(String method) {
    final model = languageModel;
    if (model == null) {
      throw StateError(
        'RagEngine.$method requires a languageModel. Provide one in the '
        'constructor, or use retrieve() to get context only.',
      );
    }
    return model;
  }
}

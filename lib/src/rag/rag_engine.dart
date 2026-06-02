import '../chunking/text_chunker.dart';
import '../embedding/embedding_model.dart';
import '../llm/language_model.dart';
import '../models/rag_document.dart';
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
/// Call [index] to add knowledge and [ask] to query it. If no [LanguageModel]
/// is supplied you can still call [retrieve] to get the relevant context — for
/// example to feed it to a model you drive yourself.
class RagEngine {
  /// Creates an engine.
  ///
  /// [embeddingModel] and [vectorStore] are required. [languageModel] is
  /// optional; without it [ask] throws and only [retrieve] is available.
  /// [chunker] and [promptBuilder] fall back to sensible defaults.
  RagEngine({
    required this.embeddingModel,
    required this.vectorStore,
    this.languageModel,
    TextChunker? chunker,
    PromptBuilder? promptBuilder,
  })  : chunker = chunker ?? const TextChunker(),
        promptBuilder = promptBuilder ?? const PromptBuilder();

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

  /// Chunks [text], embeds every chunk and adds them to the [vectorStore].
  ///
  /// Optional [metadata] is attached to each chunk produced from this call (for
  /// example `{'source': 'manual.txt'}`), and [idPrefix] seeds per-chunk ids.
  /// Returns the documents that were indexed.
  Future<List<RagDocument>> index(
    String text, {
    Map<String, Object?>? metadata,
    String? idPrefix,
  }) async {
    final chunks = chunker.chunk(text);
    if (chunks.isEmpty) return const [];
    final embeddings = await embeddingModel.embedBatch(chunks);
    final docs = <RagDocument>[];
    for (var i = 0; i < chunks.length; i++) {
      docs.add(RagDocument(
        id: idPrefix == null ? null : '$idPrefix-$i',
        text: chunks[i],
        embedding: embeddings[i],
        metadata: metadata,
      ),);
    }
    await vectorStore.add(docs);
    return docs;
  }

  /// Embeds [question] and returns the [topK] most similar indexed documents.
  Future<List<RagDocument>> retrieve(String question, {int topK = 4}) async {
    final queryVec = await embeddingModel.embed(question);
    final scored = await vectorStore.search(queryVec, topK: topK);
    return scored.map((s) => s.document).toList(growable: false);
  }

  /// Answers [question] by retrieving context and generating a grounded reply.
  ///
  /// Retrieves the [topK] best chunks, builds a grounded prompt with
  /// [promptBuilder] and streams the answer from [languageModel]. The returned
  /// [RagResult] carries both the streamed answer and the [RagResult.sources]
  /// used. Throws a [StateError] if no [languageModel] was provided.
  Future<RagResult> ask(String question, {int topK = 4}) async {
    final model = languageModel;
    if (model == null) {
      throw StateError(
        'RagEngine.ask requires a languageModel. Provide one in the '
        'constructor, or use retrieve() to get context only.',
      );
    }
    final sources = await retrieve(question, topK: topK);
    final prompt = promptBuilder.build(question, sources);
    return RagResult(answer: model.generate(prompt), sources: sources);
  }
}

import 'package:on_device_rag/on_device_rag.dart';

/// Demonstrates a complete on-device RAG flow with zero native dependencies.
///
/// Run with: `dart run example/on_device_rag_example.dart`
Future<void> main() async {
  // 1. Build an engine. The default hashing embedder needs no model download.
  final engine = RagEngine(
    embeddingModel: HashingEmbeddingModel(dimensions: 256),
    vectorStore: InMemoryVectorStore(),
    // languageModel: MyGemmaModel(), // plug in an on-device LLM for ask().
  );

  // 2. Index some knowledge. Long text is chunked automatically.
  await engine.index(
    'Flutter is an open-source UI toolkit by Google for building apps from a '
    'single codebase. Dart is the language Flutter uses. '
    'RAG stands for retrieval-augmented generation: relevant text is fetched '
    'and given to a language model so its answers stay grounded in your data.',
    metadata: {'source': 'intro.txt'},
  );

  // 3. Retrieve context for a question (no LLM required).
  final hits = await engine.retrieve('What does RAG mean?', topK: 2);
  for (final doc in hits) {
    print('• ${doc.text}');
  }

  // 4. With a LanguageModel set, call ask() for a grounded streamed answer:
  // final result = await engine.ask('What does RAG mean?');
  // await for (final token in result.answer) stdout.write(token);
}

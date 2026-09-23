import 'package:on_device_rag/on_device_rag.dart';

/// A fake LLM for the example.
class EchoLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    yield 'answer';
  }
}

Future<void> main() async {
  // Tune chunking and retrieval for your content.
  final engine = RagEngine(
    languageModel: EchoLLM(),
    // Smaller chunks give more precise retrieval, larger ones more context.
    // Overlap stops answers being cut off at chunk boundaries.
    chunker: const TextChunker(chunkSize: 200, overlap: 40),
    // Keep prompts short for small on-device context windows and label each
    // chunk with its source.
    promptBuilder:
        const PromptBuilder(maxContextChars: 1200, sourceKey: 'source'),
    topK: 5,
  );

  final longText = List.generate(
    50,
    (i) => 'Paragraph $i: Flutter widget $i is a UI component that renders '
        'on screen.',
  ).join(' ');

  await engine.addDocument(
    id: 'long_doc',
    text: longText,
    metadata: {'source': 'widgets.md'},
  );

  // diversity > 0 uses Maximal Marginal Relevance so near-duplicate chunks
  // don't crowd out other useful context.
  final result = await engine.query('What is widget 25?', diversity: 0.3);
  print('Answer: ${result.answer}');
  print('Chunks used: ${result.sources.length}');
  print(result.prompt);
}

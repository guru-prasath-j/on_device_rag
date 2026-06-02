// This is the main example shown on pub.dev.
// See the example/ folder for more detailed examples:
//   basic_example.dart         — minimal usage
//   multi_document_example.dart — querying across multiple docs
//   streaming_example.dart      — stream tokens as they arrive
//   custom_chunking_example.dart — fine-tune chunk size and topK

import 'package:on_device_rag/on_device_rag.dart';

/// Minimal LLM stub — replace with your real on-device or remote model.
class EchoLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    yield 'This is where your LLM answer would appear, grounded in the retrieved context.';
  }
}

Future<void> main() async {
  // 1. Create the engine with your LLM
  final engine = RagEngine(llm: EchoLLM());

  // 2. Add content to search over
  await engine.addDocument(
    id: 'intro',
    text: '''
      on_device_rag is a pure-Dart RAG engine that runs entirely offline.
      It chunks your text, embeds each chunk, and lets you query across
      them with semantic similarity — no internet connection required.
    ''',
  );

  // 3. Ask a question
  final result = await engine.query('Does this package need the internet?');
  print('Answer: ${result.answer}');
}
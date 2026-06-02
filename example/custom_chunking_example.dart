import 'package:on_device_rag/on_device_rag.dart';

class EchoLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* { yield 'answer'; }
}

Future<void> main() async {
  // Fine-tune chunking for your content type
  final engine = RagEngine(
    llm: EchoLLM(),
    chunkSize: 200,    // smaller = more precise, larger = more context
    chunkOverlap: 40,  // overlap prevents answers being cut off at chunk boundaries
    topK: 5,           // how many chunks to retrieve per query
  );

  // Long document — engine chunks it automatically
  final longText = List.generate(
    50,
    (i) => 'Paragraph $i: Flutter widget $i is a UI component that renders on screen.',
  ).join(' ');

  await engine.addDocument(id: 'long_doc', text: longText);

  final result = await engine.query('What is widget 25?');
  print('Answer: ${result.answer}');
  print('Chunks used: ${result.sources.length}');
}
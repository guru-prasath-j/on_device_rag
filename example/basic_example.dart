import 'package:on_device_rag/on_device_rag.dart';

// A minimal fake LLM that echoes the context — replace with your real model.
class EchoLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    // In a real app, call Ollama, a TFLite model, llama.cpp, etc.
    yield 'Based on the provided text: $prompt';
  }
}

Future<void> main() async {
  final engine = RagEngine(llm: EchoLLM());

  // Add your content
  await engine.addDocument(
    id: 'flutter_intro',
    text: '''
      Flutter is an open-source UI toolkit created by Google.
      It allows developers to build natively compiled applications
      for mobile, web, and desktop from a single codebase.
      Flutter uses the Dart programming language and provides
      its own rendering engine called Skia / Impeller.
    ''',
  );

  // Ask a question
  final result = await engine.query('Who created Flutter?');
  print('Answer: ${result.answer}');
  print('Sources: ${result.sources}');
}
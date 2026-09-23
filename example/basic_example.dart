import 'package:on_device_rag/on_device_rag.dart';

/// A fake LLM. In a real app, call Ollama, llama.cpp, flutter_gemma, etc.
class EchoLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    yield 'Based on the provided text: ${prompt.length} prompt characters';
  }
}

Future<void> main() async {
  final engine = RagEngine(languageModel: EchoLLM());

  await engine.addDocument(
    id: 'flutter_intro',
    text: '''
      Flutter is an open-source UI toolkit created by Google.
      It allows developers to build natively compiled applications
      for mobile, web, and desktop from a single codebase.
      Flutter uses the Dart programming language and renders with Impeller.
    ''',
  );

  final result = await engine.query('Who created Flutter?');
  print('Answer: ${result.answer}');
  for (final (i, source) in result.sources.indexed) {
    print('  [${i + 1}] score ${result.scores[i].toStringAsFixed(2)}: '
        '${source.text}');
  }

  // Without an LLM you can still retrieve context for your own pipeline.
  final context = await engine.retrieve('What language does Flutter use?');
  print('Top chunk: ${context.first.text}');
}

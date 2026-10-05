import 'dart:io';

import 'package:on_device_rag/on_device_rag.dart';

/// Stand-in for any LLM client: an on-device runtime such as `flutter_gemma`
/// or `llama_cpp_dart`, or an HTTP API. Only the call shape matters.
class FakeLlmClient {
  /// Returns a completion for [prompt].
  Future<String> complete(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return prompt.contains('Dart')
        ? 'Dart compiles to native code and JavaScript.'
        : "I don't know.";
  }
}

Future<void> main() async {
  final client = FakeLlmClient();

  // Adapt the client with one line instead of writing a LanguageModel class.
  // Use the default constructor instead when your client streams tokens:
  // FunctionLanguageModel((prompt) => client.stream(prompt)).
  final engine = RagEngine(
    languageModel: FunctionLanguageModel.fromFuture(client.complete),
    // Keep Markdown sections together when chunking.
    chunker: const TextChunker(chunkSize: 400, preserveParagraphs: true),
  );

  await engine.addDocument(
    id: 'dart-faq',
    text: '# Dart\n\n'
        'Dart compiles ahead of time to native machine code and to '
        'JavaScript or WebAssembly for the web.\n\n'
        '# Flutter\n\n'
        'Flutter is a UI toolkit written in Dart.',
  );

  final answer = await engine.query('How does Dart compile?');
  stdout.writeln(answer.answer);
}

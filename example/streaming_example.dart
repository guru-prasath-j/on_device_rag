import 'dart:io';
import 'package:on_device_rag/on_device_rag.dart';

// Simulates a streaming LLM response word by word
class StreamingLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    final words = ['Flutter', 'is', 'a', 'cross-platform', 'UI', 'toolkit', '.'];
    for (final word in words) {
      await Future.delayed(const Duration(milliseconds: 80));
      yield word + ' ';
    }
  }
}

Future<void> main() async {
  final engine = RagEngine(llm: StreamingLLM());

  await engine.addDocument(
    id: 'doc',
    text: 'Flutter is a cross-platform UI toolkit built by Google '
          'for building beautiful native apps from a single codebase.',
  );

  print('Streaming answer:');

  // Stream tokens as they arrive — ideal for chat UIs
  await for (final token in engine.queryStream('What is Flutter?')) {
    stdout.write(token);
  }
  print('');
}
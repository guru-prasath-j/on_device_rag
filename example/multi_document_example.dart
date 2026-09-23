import 'package:on_device_rag/on_device_rag.dart';

/// A fake LLM for the example.
class EchoLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    yield 'Answer from context: ${prompt.substring(0, 60)}...';
  }
}

Future<void> main() async {
  final engine = RagEngine(languageModel: EchoLLM(), topK: 3);

  await engine.addDocument(
    id: 'history',
    metadata: {'subject': 'history'},
    text: 'The French Revolution began in 1789. It was a period of radical '
        'political and social transformation in France. Key events included '
        'the storming of the Bastille on July 14, 1789.',
  );
  await engine.addDocument(
    id: 'science',
    metadata: {'subject': 'science'},
    text: 'Photosynthesis is the process by which plants convert sunlight into '
        'energy. Plants absorb carbon dioxide from the air and water from the '
        'soil. Chlorophyll captures sunlight to power this process.',
  );
  await engine.addDocument(
    id: 'tech',
    metadata: {'subject': 'tech'},
    text: 'Dart is a client-optimised programming language developed by '
        'Google. It supports both AOT and JIT compilation and is the language '
        'used by the Flutter framework.',
  );

  // Queries search across all documents.
  final r1 = await engine.query('What happened in 1789?');
  print('History: ${r1.answer} (from ${r1.sourceDocumentIds})');

  // ...or only some of them.
  final r2 = await engine.query(
    'How do plants make food?',
    where: (doc) => doc.metadata['subject'] == 'science',
    minScore: 0.05,
  );
  print('Science: ${r2.answer} (from ${r2.sourceDocumentIds})');

  // Re-adding an id replaces it; removeDocument deletes it.
  await engine.removeDocument('history');
  print('Chunks left: ${await engine.vectorStore.length}');
}

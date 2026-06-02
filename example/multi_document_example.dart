import 'package:on_device_rag/on_device_rag.dart';

class EchoLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    yield 'Answer from context: ' + prompt.substring(0, 100) + '...';
  }
}

Future<void> main() async {
  final engine = RagEngine(llm: EchoLLM(), topK: 3);

  // Index multiple documents
  await engine.addDocument(
    id: 'history',
    text: 'The French Revolution began in 1789. It was a period of radical political '
          'and social transformation in France. Key events included the storming of '
          'the Bastille on July 14, 1789, and the Declaration of the Rights of Man.',
  );

  await engine.addDocument(
    id: 'science',
    text: 'Photosynthesis is the process by which plants convert sunlight into energy. '
          'Plants absorb carbon dioxide from the air and water from the soil. '
          'Chlorophyll in the leaves captures sunlight to power this process.',
  );

  await engine.addDocument(
    id: 'tech',
    text: 'Dart is a client-optimised programming language developed by Google. '
          'It is strongly typed, supports both AOT and JIT compilation, '
          'and is the language used by the Flutter framework.',
  );

  // Each query searches across all documents
  final r1 = await engine.query('What happened in 1789?');
  print('History answer: ${r1.answer}');

  final r2 = await engine.query('How do plants make food?');
  print('Science answer: ${r2.answer}');

  final r3 = await engine.query('What language does Flutter use?');
  print('Tech answer: ${r3.answer}');
}
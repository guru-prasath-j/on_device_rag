import 'package:on_device_rag/on_device_rag.dart';
import 'package:test/test.dart';

/// A tiny fake model that echoes the retrieved context, for deterministic tests.
class _EchoModel implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    yield 'ANSWER';
  }
}

void main() {
  group('VectorMath', () {
    test('cosineSimilarity of identical vectors is 1', () {
      expect(VectorMath.cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1, 1e-9));
    });
    test('cosineSimilarity of orthogonal vectors is 0', () {
      expect(VectorMath.cosineSimilarity([1, 0], [0, 1]), closeTo(0, 1e-9));
    });
    test('zero vector yields 0', () {
      expect(VectorMath.cosineSimilarity([0, 0], [1, 1]), 0);
    });
    test('normalize gives unit length', () {
      expect(VectorMath.norm(VectorMath.normalize([3, 4])), closeTo(1, 1e-9));
    });
  });

  group('TextChunker', () {
    test('blank text yields no chunks', () {
      expect(const TextChunker().chunk('   '), isEmpty);
    });
    test('short text stays a single chunk', () {
      expect(const TextChunker().chunk('hello world'), ['hello world']);
    });
    test('long text splits with overlap', () {
      final text = List.filled(50, 'word').join(' ');
      final chunks = const TextChunker(chunkSize: 60, overlap: 10).chunk(text);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length <= 60), isTrue);
    });
  });

  group('HashingEmbeddingModel', () {
    test('produces vectors of the declared dimension', () async {
      final m = HashingEmbeddingModel(dimensions: 64);
      final v = await m.embed('the quick brown fox');
      expect(v.length, 64);
    });
    test('is deterministic', () async {
      final m = HashingEmbeddingModel(dimensions: 64);
      expect(await m.embed('hello'), await m.embed('hello'));
    });
    test('similar text scores higher than unrelated text', () async {
      final m = HashingEmbeddingModel(dimensions: 256);
      final a = await m.embed('cats and dogs are popular pets');
      final b = await m.embed('cats and dogs make great pets');
      final c = await m.embed('quantum chromodynamics in particle physics');
      expect(VectorMath.cosineSimilarity(a, b),
          greaterThan(VectorMath.cosineSimilarity(a, c)),);
    });
  });

  group('InMemoryVectorStore', () {
    test('round-trips through JSON', () async {
      final m = HashingEmbeddingModel(dimensions: 32);
      final store = InMemoryVectorStore();
      await store.add([
        RagDocument(text: 'alpha', embedding: await m.embed('alpha')),
      ]);
      final restored =
          InMemoryVectorStore.fromJson(store.toJson());
      expect(await restored.length, 1);
    });
  });

  group('RagEngine', () {
    test('indexes and retrieves the most relevant chunk', () async {
      final engine = RagEngine(
        embeddingModel: HashingEmbeddingModel(dimensions: 256),
        vectorStore: InMemoryVectorStore(),
      );
      await engine.index(
        'The Eiffel Tower is in Paris. The Colosseum is in Rome.',
      );
      final hits = await engine.retrieve('Where is the Eiffel Tower?', topK: 1);
      expect(hits, isNotEmpty);
      expect(hits.first.text.toLowerCase(), contains('eiffel'));
    });

    test('ask streams an answer and exposes sources', () async {
      final engine = RagEngine(
        embeddingModel: HashingEmbeddingModel(dimensions: 128),
        vectorStore: InMemoryVectorStore(),
        languageModel: _EchoModel(),
      );
      await engine.index('Dart is a programming language by Google.');
      final result = await engine.ask('What is Dart?');
      expect(result.sources, isNotEmpty);
      expect(await result.answer.join(), 'ANSWER');
    });

    test('ask without a language model throws', () async {
      final engine = RagEngine(
        embeddingModel: HashingEmbeddingModel(dimensions: 32),
        vectorStore: InMemoryVectorStore(),
      );
      await engine.index('some text');
      expect(() => engine.ask('q'), throwsStateError);
    });
  });
}

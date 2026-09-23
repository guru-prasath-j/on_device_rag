import 'dart:convert';

import 'package:on_device_rag/on_device_rag.dart';
import 'package:test/test.dart';

/// A tiny fake model that returns a fixed answer, for deterministic tests.
class _EchoModel implements LanguageModel {
  String? lastPrompt;

  @override
  Stream<String> generate(String prompt) async* {
    lastPrompt = prompt;
    yield 'ANS';
    yield 'WER';
  }
}

void main() {
  group('VectorMath', () {
    test('cosineSimilarity of identical vectors is 1', () {
      expect(
        VectorMath.cosineSimilarity([1, 2, 3], [1, 2, 3]),
        closeTo(1, 1e-9),
      );
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
    test('dotProduct rejects mismatched lengths', () {
      expect(() => VectorMath.dotProduct([1], [1, 2]), throwsArgumentError);
    });
    test('MMR prefers diverse results', () {
      final query = [1.0, 0.0];
      final candidates = [
        [1.0, 0.05],
        [1.0, 0.06], // near-duplicate of the first
        [0.7, 0.7],
      ];
      expect(
        VectorMath.maximalMarginalRelevance(query, candidates, k: 2, lambda: 1),
        [0, 1],
      );
      expect(
        VectorMath.maximalMarginalRelevance(query, candidates,
            k: 2, lambda: 0.3),
        [0, 2],
      );
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
    test('never splits words when boundaries are enabled', () {
      final text = List.generate(200, (i) => 'token$i').join(' ');
      final chunks = const TextChunker(chunkSize: 80, overlap: 20).chunk(text);
      final words = text.split(' ').toSet();
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(80));
        for (final w in c.split(' ')) {
          expect(words, contains(w), reason: 'split word "$w" in "$c"');
        }
      }
      // Every word survives chunking.
      final seen = chunks.expand((c) => c.split(' ')).toSet();
      expect(seen, containsAll(words));
    });
    test('prefers sentence boundaries', () {
      const text =
          'The first sentence is here. The second sentence follows it. '
          'A third one ends the paragraph.';
      final chunks = const TextChunker(chunkSize: 70, overlap: 0).chunk(text);
      expect(chunks.first, endsWith('.'));
    });
    test('raw mode cuts exactly at chunkSize', () {
      final text = 'a' * 250;
      final chunks = const TextChunker(
        chunkSize: 100,
        overlap: 0,
        splitOnBoundaries: false,
      ).chunk(text);
      expect(chunks.map((c) => c.length), [100, 100, 50]);
    });
  });

  group('HashingEmbeddingModel', () {
    test('produces vectors of the declared dimension', () async {
      const m = HashingEmbeddingModel(dimensions: 64);
      final v = await m.embed('the quick brown fox');
      expect(v.length, 64);
    });
    test('is deterministic', () async {
      const m = HashingEmbeddingModel(dimensions: 64);
      expect(await m.embed('hello'), await m.embed('hello'));
    });
    test('uses a stable, platform-independent hash', () {
      // Reference FNV-1a 32-bit values.
      expect(HashingEmbeddingModel.fnv1a32('a'), 0xe40c292c);
      expect(HashingEmbeddingModel.fnv1a32('foobar'), 0xbf9cf968);
    });
    test('similar text scores higher than unrelated text', () async {
      const m = HashingEmbeddingModel(dimensions: 256);
      final a = await m.embed('cats and dogs are popular pets');
      final b = await m.embed('cats and dogs make great pets');
      final c = await m.embed('quantum chromodynamics in particle physics');
      expect(
        VectorMath.cosineSimilarity(a, b),
        greaterThan(VectorMath.cosineSimilarity(a, c)),
      );
    });
    test('embeds non-English text', () async {
      const m = HashingEmbeddingModel(dimensions: 128);
      final tamil = await m.embed('தமிழ் மொழி');
      final accented = await m.embed('café crème brûlée');
      expect(VectorMath.norm(tamil), closeTo(1, 1e-9));
      expect(VectorMath.norm(accented), closeTo(1, 1e-9));
      expect(HashingEmbeddingModel.tokenize('Café, crème!'), ['café', 'crème']);
    });
  });

  group('InMemoryVectorStore', () {
    const m = HashingEmbeddingModel(dimensions: 32);

    Future<InMemoryVectorStore> storeOf(Map<String, String> docs) async {
      final store = InMemoryVectorStore();
      await store.add([
        for (final e in docs.entries)
          RagDocument(
            id: e.key,
            text: e.value,
            embedding: await m.embed(e.value),
            metadata: {'group': e.key.substring(0, 1)},
          ),
      ]);
      return store;
    }

    test('round-trips through JSON', () async {
      final store = await storeOf({'a1': 'alpha'});
      final json =
          jsonDecode(jsonEncode(store.toJson())) as Map<String, Object?>;
      final restored = InMemoryVectorStore.fromJson(json);
      expect(await restored.length, 1);
      expect(restored.documents.single.metadata['group'], 'a');
    });

    test('rejects documents without embeddings', () {
      expect(
        () => InMemoryVectorStore().add([RagDocument(text: 'x')]),
        throwsArgumentError,
      );
    });

    test('filters searches and removes by predicate', () async {
      final store = await storeOf({
        'a1': 'apples are red',
        'a2': 'apples are green',
        'b1': 'apples are tasty',
      });
      final hits = await store.search(
        await m.embed('apples'),
        topK: 10,
        where: (d) => d.metadata['group'] == 'b',
      );
      expect(hits.map((h) => h.document.id), ['b1']);
      expect(await store.removeWhere((d) => d.metadata['group'] == 'a'), 2);
      expect(await store.length, 1);
    });
  });

  group('PromptBuilder', () {
    test('numbers context and fills the template', () {
      final prompt = const PromptBuilder().build('Q?', [
        RagDocument(text: 'one'),
        RagDocument(text: 'two'),
      ]);
      expect(prompt, contains('[1] one'));
      expect(prompt, contains('[2] two'));
      expect(prompt, contains('Question: Q?'));
    });
    test('labels sources and respects a context budget', () {
      final prompt = const PromptBuilder(maxContextChars: 30, sourceKey: 'src')
          .build('Q?', [
        RagDocument(text: 'first chunk', metadata: {'src': 'a.txt'}),
        RagDocument(text: 'second chunk that will not fit'),
      ]);
      expect(prompt, contains('[1] (a.txt) first chunk'));
      expect(prompt, isNot(contains('second chunk')));
    });
    test('handles empty context', () {
      expect(
        const PromptBuilder().build('Q?', const []),
        contains('No relevant context found.'),
      );
    });
  });

  group('RagEngine', () {
    test('works with defaults and retrieves the most relevant chunk', () async {
      final engine = RagEngine();
      await engine.index(
        'The Eiffel Tower is in Paris. The Colosseum is in Rome.',
      );
      final hits = await engine.retrieve('Where is the Eiffel Tower?', topK: 1);
      expect(hits, isNotEmpty);
      expect(hits.first.text.toLowerCase(), contains('eiffel'));
    });

    test('ask streams an answer and exposes sources and prompt', () async {
      final model = _EchoModel();
      final engine = RagEngine(languageModel: model);
      await engine.index('Dart is a programming language by Google.');
      final result = await engine.ask('What is Dart?');
      expect(result.sources, isNotEmpty);
      expect(result.scores, hasLength(result.sources.length));
      expect(await result.answer.join(), 'ANSWER');
      expect(result.prompt, model.lastPrompt);
    });

    test('query returns the full answer; queryStream streams it', () async {
      final engine = RagEngine(languageModel: _EchoModel());
      await engine.addDocument(id: 'dart', text: 'Dart is made by Google.');
      final answer = await engine.query('Who makes Dart?');
      expect(answer.answer, 'ANSWER');
      expect(answer.sourceDocumentIds, ['dart']);
      expect(
          await engine.queryStream('Who makes Dart?').toList(), ['ANS', 'WER']);
    });

    test('addDocument replaces and removeDocument deletes', () async {
      final engine =
          RagEngine(chunker: const TextChunker(chunkSize: 40, overlap: 0));
      await engine.addDocument(id: 'doc', text: 'x ' * 100);
      await engine.addDocument(id: 'doc', text: 'short replacement');
      expect(await engine.vectorStore.length, 1);
      await engine.addDocument(id: 'other', text: 'another document');
      expect(await engine.removeDocument('doc'), 1);
      expect(await engine.vectorStore.length, 1);
    });

    test('where, minScore and diversity shape retrieval', () async {
      final engine = RagEngine(topK: 2);
      await engine.addDocument(id: 'fruit', text: 'Bananas are yellow fruit.');
      await engine.addDocument(id: 'cars', text: 'Yellow cars are fast.');
      final onlyCars = await engine.retrieve(
        'yellow',
        where: (d) => d.metadata[RagEngine.documentIdKey] == 'cars',
      );
      expect(onlyCars.single.metadata['documentId'], 'cars');

      final none = await engine.retrieve('yellow', minScore: 0.9999);
      expect(none, isEmpty);

      final diverse = await engine.retrieve('yellow', diversity: 0.5);
      expect(diverse, hasLength(2));
      expect(() => engine.retrieve('x', diversity: 2), throwsArgumentError);
    });

    test('ask without a language model throws', () async {
      final engine = RagEngine();
      await engine.index('some text');
      expect(() => engine.ask('q'), throwsStateError);
      expect(() => engine.query('q'), throwsStateError);
    });

    test('chunks carry their index in metadata', () async {
      final engine = RagEngine(
        chunker: const TextChunker(chunkSize: 20, overlap: 0),
      );
      final docs = await engine.index('one two three four five six seven');
      expect(
        docs.map((d) => d.metadata[RagEngine.chunkIndexKey]),
        List.generate(docs.length, (i) => i),
      );
    });
  });
}

# on_device_rag

**Ask questions about any text and get answers grounded in that text,
entirely on the device. No server, no API key, no data leaving the phone.**

[![pub package](https://img.shields.io/pub/v/on_device_rag.svg)](https://pub.dev/packages/on_device_rag)
[![pub points](https://img.shields.io/pub/points/on_device_rag)](https://pub.dev/packages/on_device_rag/score)
[![CI](https://github.com/guru-prasath-j/on_device_rag/actions/workflows/ci.yml/badge.svg)](https://github.com/guru-prasath-j/on_device_rag/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`on_device_rag` is a small, pure-Dart retrieval-augmented generation (RAG)
engine. It splits your content into chunks, embeds them, finds the chunks most
relevant to a question, and builds a prompt that keeps your LLM grounded in
them.

## Features

- **Zero dependencies**: pure Dart on Android, iOS, web, desktop and CLI.
- **Works out of the box**: a built-in offline embedder and in-memory vector
  store, so `RagEngine()` is usable with no setup.
- **Bring your own models**: plug in any LLM, embedding model or vector store
  through three small interfaces.
- **Documents you can manage**: add, replace and remove by id; filter
  retrieval by metadata.
- **Better context**: sentence-aware chunking, similarity thresholds,
  diversity re-ranking (MMR) and a prompt size budget for small on-device
  context windows.
- **Persistable index**: save and restore the store as JSON. Embeddings are
  stable across platforms and SDK versions.
- **Multilingual**: Unicode-aware tokenisation.

## Install

```yaml
dependencies:
  on_device_rag: ^0.2.0
```

## Quick start

```dart
import 'package:on_device_rag/on_device_rag.dart';

// 1. Wrap your LLM (llama.cpp, flutter_gemma, Ollama, a cloud API, ...).
class MyLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    yield 'Answer based on the provided context.';
  }
}

Future<void> main() async {
  final engine = RagEngine(languageModel: MyLLM());

  // 2. Index your content.
  await engine.addDocument(
    id: 'flutter',
    text: 'Flutter is an open-source UI toolkit by Google. It builds '
        'natively compiled apps for mobile, web and desktop from one '
        'Dart codebase.',
  );

  // 3. Ask.
  final result = await engine.query('What is Flutter?');
  print(result.answer);
  print(result.sourceDocumentIds); // [flutter]
}
```

## Usage

### Streaming answers

```dart
await for (final token in engine.queryStream('Explain the main idea')) {
  stdout.write(token);
}

// Or keep the sources and the stream together:
final result = await engine.ask('Explain the main idea');
print(result.sources.length);
await for (final token in result.answer) { /* ... */ }
```

### Multiple documents, filtering and removal

```dart
await engine.addDocument(id: 'ch1', text: chapter1, metadata: {'book': 'A'});
await engine.addDocument(id: 'ch2', text: chapter2, metadata: {'book': 'B'});

final answer = await engine.query(
  'What happens next?',
  where: (doc) => doc.metadata['book'] == 'A', // only book A
  minScore: 0.1,                               // drop weak matches
);

await engine.addDocument(id: 'ch1', text: revisedChapter1); // replaces ch1
await engine.removeDocument('ch2');
```

### Retrieval only

No LLM needed if you just want the context:

```dart
final engine = RagEngine();
await engine.addDocument(id: 'notes', text: notes);

final hits = await engine.retrieveScored('deadline', topK: 3);
for (final hit in hits) {
  print('${hit.score.toStringAsFixed(2)}  ${hit.document.text}');
}
```

### Tuning

```dart
final engine = RagEngine(
  languageModel: MyLLM(),
  chunker: const TextChunker(chunkSize: 300, overlap: 50),
  promptBuilder: const PromptBuilder(
    maxContextChars: 1500, // fit a small on-device context window
    sourceKey: 'source',   // label chunks with metadata['source']
  ),
  topK: 5,
);

// Re-rank for variety when your corpus has near-duplicate passages.
final result = await engine.query('Summarise the options', diversity: 0.3);
```

### Semantic embeddings

`HashingEmbeddingModel` is lexical: it matches shared words, not meaning. For
semantic search, wrap a sentence-embedding model:

```dart
class MiniLmEmbeddings extends EmbeddingModel {
  @override
  int get dimensions => 384;

  @override
  Future<List<double>> embed(String text) => myTfliteModel.embed(text);
}

final engine = RagEngine(
  embeddingModel: MiniLmEmbeddings(),
  languageModel: MyLLM(),
);
```

### Persisting the index

```dart
final store = InMemoryVectorStore();
final engine = RagEngine(vectorStore: store);
// ... index content ...
await File('index.json').writeAsString(jsonEncode(store.toJson()));

// Later:
final restored = InMemoryVectorStore.fromJson(
  jsonDecode(await File('index.json').readAsString()) as Map<String, Object?>,
);
```

For a database-backed index, implement `VectorStore` (`add`, `search`,
`removeWhere`, `clear`, `length`).

### In a Flutter widget

```dart
class StudyAssistant extends StatefulWidget {
  const StudyAssistant({super.key});

  @override
  State<StudyAssistant> createState() => _StudyAssistantState();
}

class _StudyAssistantState extends State<StudyAssistant> {
  final _engine = RagEngine(languageModel: MyLLM());
  late final Future<void> _ready =
      _engine.addDocument(id: 'notes', text: myStudyNotes);
  String _answer = '';

  Future<void> _ask(String question) async {
    await _ready;
    final result = await _engine.query(question);
    setState(() => _answer = result.answer);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onSubmitted: _ask,
          decoration: const InputDecoration(labelText: 'Ask a question'),
        ),
        Text(_answer),
      ],
    );
  }
}
```

## How it works

```
index time                             query time

text                                   question
  │                                      │
  ▼                                      ▼
TextChunker ─► sentence-aware chunks   EmbeddingModel ─► query vector
  │                                      │
  ▼                                      ▼
EmbeddingModel ─► one vector per chunk VectorStore.search ─► top-K (+ filter, MMR)
  │                                      │
  ▼                                      ▼
VectorStore ◄────────────────────────  PromptBuilder ─► grounded prompt
                                         │
                                         ▼
                                       LanguageModel ─► streamed answer
```

## API

| Class | Role |
|-------|------|
| `RagEngine` | Entry point: `addDocument`, `removeDocument`, `index`, `retrieve`, `retrieveScored`, `ask`, `query`, `queryStream` |
| `LanguageModel` | Interface for your LLM |
| `EmbeddingModel` | Interface for embedders |
| `HashingEmbeddingModel` | Built-in offline lexical embedder |
| `VectorStore` | Interface for storage |
| `InMemoryVectorStore` | Built-in store with JSON persistence |
| `TextChunker` | Sentence-aware overlapping chunking |
| `PromptBuilder` | Grounded prompt template with a size budget |
| `RagDocument` / `ScoredDocument` | A stored chunk / a chunk with its score |
| `RagResult` / `RagAnswer` | Streamed / complete answer with sources |
| `VectorMath` | Cosine similarity, normalisation, MMR |

## Contributing

Issues and pull requests are welcome on
[GitHub](https://github.com/guru-prasath-j/on_device_rag).

## License

MIT, see [LICENSE](LICENSE).

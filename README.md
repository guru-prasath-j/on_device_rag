# on_device_rag

**Ask questions about any text — and get answers grounded in that text — entirely on your device, with no internet connection required.**

It works by breaking your content into small pieces, finding the most relevant ones for each question, and feeding them to your AI model to generate a focused, accurate answer.

[![pub.dev](https://img.shields.io/pub/v/on_device_rag.svg)](https://pub.dev/packages/on_device_rag)
[![CI](https://github.com/guru-prasath-j/on_device_rag/actions/workflows/ci.yml/badge.svg)](https://github.com/guru-prasath-j/on_device_rag/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## What it does

You give it text (a document, notes, a book chapter — anything). It splits it into chunks, creates a searchable index, and lets you query it. When you ask a question, it finds the most relevant chunks and builds a prompt that gives your LLM just the right context to answer accurately — no hallucination, no guesswork.

Everything runs locally. No API calls. No data leaves the device.

---

## Features

- **Zero dependencies** — pure Dart, works on every Flutter and Dart platform (mobile, desktop, web, CLI)
- **Plug in any LLM** — bring your own language model via a simple interface
- **Smart chunking** — splits text with configurable size and overlap to preserve context
- **Vector similarity search** — cosine similarity over in-memory embeddings
- **Fully offline** — no network calls, no API keys needed for the core engine
- **Swappable everything** — embedding model, vector store, and LLM are all interfaces you can replace

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  on_device_rag: ^0.1.0
```

Then run:

```bash
dart pub get
```

---

## Quick start

```dart
import 'package:on_device_rag/on_device_rag.dart';

// 1. Implement LanguageModel with your LLM of choice
class MyLLM implements LanguageModel {
  @override
  Stream<String> generate(String prompt) async* {
    // Call your local model here — Ollama, llama.cpp, on-device model, etc.
    yield 'Answer based on the provided context.';
  }
}

void main() async {
  final engine = RagEngine(llm: MyLLM());

  // 2. Index your content
  await engine.addDocument(
    id: 'doc1',
    text: 'Flutter is an open-source UI toolkit by Google. '
          'It lets you build natively compiled apps for mobile, '
          'web, and desktop from a single codebase using Dart.',
  );

  // 3. Ask questions
  final result = await engine.query('What is Flutter?');
  print(result.answer);
  // -> Answer grounded in the text you provided
}
```

---

## Examples

### Basic usage

```dart
final engine = RagEngine(llm: MyLLM());

await engine.addDocument(id: 'notes', text: yourTextHere);

final result = await engine.query('Summarise the key points');
print(result.answer);
print('Sources used: ${result.sources}');
```

### Multiple documents

```dart
final engine = RagEngine(llm: MyLLM());

await engine.addDocument(id: 'chapter1', text: chapter1Text);
await engine.addDocument(id: 'chapter2', text: chapter2Text);
await engine.addDocument(id: 'chapter3', text: chapter3Text);

// Queries search across all documents automatically
final result = await engine.query('What happens in chapter 2?');
```

### Streaming answers

```dart
final engine = RagEngine(llm: MyLLM());
await engine.addDocument(id: 'doc1', text: content);

// Stream tokens as they arrive — great for chat UIs
await for (final token in engine.queryStream('Explain the main idea')) {
  stdout.write(token); // Print each token as it streams in
}
```

### Custom chunk size

```dart
final engine = RagEngine(
  llm: MyLLM(),
  chunkSize: 300,    // smaller chunks = more precise retrieval
  chunkOverlap: 50,  // overlap preserves context across boundaries
  topK: 3,           // how many chunks to include in the prompt
);
```

### Bring your own embedding model

```dart
class MyEmbeddingModel implements EmbeddingModel {
  @override
  Future<List<double>> embed(String text) async {
    // Use any embedding model — TFLite, ONNX, API, etc.
    return myModel.getEmbedding(text);
  }
}

final engine = RagEngine(
  llm: MyLLM(),
  embeddingModel: MyEmbeddingModel(),
);
```

### Bring your own vector store

```dart
class PersistentVectorStore implements VectorStore {
  // Implement with SQLite, Hive, or any local DB
  // to persist your index across app restarts
}

final engine = RagEngine(
  llm: MyLLM(),
  vectorStore: PersistentVectorStore(),
);
```

### Use in a Flutter widget

```dart
class StudyAssistant extends StatefulWidget {
  const StudyAssistant({super.key});
  @override
  State<StudyAssistant> createState() => _StudyAssistantState();
}

class _StudyAssistantState extends State<StudyAssistant> {
  final _engine = RagEngine(llm: MyLLM());
  String _answer = '';

  @override
  void initState() {
    super.initState();
    _engine.addDocument(id: 'notes', text: myStudyNotes);
  }

  Future<void> _ask(String question) async {
    final result = await _engine.query(question);
    setState(() => _answer = result.answer);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(onSubmitted: _ask, decoration: const InputDecoration(labelText: 'Ask a question')),
        Text(_answer),
      ],
    );
  }
}
```

---

## How it works

```
Your text
   |
   v
TextChunker  ──►  splits into overlapping chunks (e.g. 500 chars, 50 overlap)
   |
   v
EmbeddingModel  ──►  converts each chunk into a list of numbers (a vector)
   |
   v
VectorStore  ──►  stores all vectors in memory (or your custom store)

── Query time ──

Your question
   |
   v
EmbeddingModel  ──►  embed the question
   |
   v
VectorStore.search()  ──►  find the top-K most similar chunks (cosine similarity)
   |
   v
PromptBuilder  ──►  wrap chunks + question into a structured prompt
   |
   v
LanguageModel  ──►  stream the final answer
```

---

## API reference

| Class | Description |
|-------|-------------|
| `RagEngine` | Main entry point. Call `addDocument()`, `query()`, `queryStream()` |
| `LanguageModel` | Interface — implement this with your LLM |
| `EmbeddingModel` | Interface — implement for custom embeddings |
| `HashingEmbeddingModel` | Default embedding model, zero dependencies |
| `VectorStore` | Interface — implement for custom/persistent storage |
| `InMemoryVectorStore` | Default in-memory vector store |
| `TextChunker` | Splits text into overlapping chunks |
| `RagDocument` | Model representing a stored document chunk |
| `RagResult` | Result of a query: `answer`, `sources`, `prompt` |
| `PromptBuilder` | Assembles the grounded prompt sent to the LLM |
| `VectorMath` | Cosine similarity and vector normalization utilities |

---

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

---

## License

MIT — see [LICENSE](LICENSE)

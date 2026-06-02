# on_device_rag

A lightweight, **pure-Dart** retrieval-augmented-generation (RAG) engine that runs entirely on-device — no servers, no native dependencies, works on every Flutter and Dart platform (Android, iOS, web, desktop).

It gives you the four building blocks of RAG out of the box and lets you swap any of them for your own implementation:

- **Chunking** — split long text into overlapping, retrieval-friendly pieces.
- **Embeddings** — turn text into vectors. Ships with a zero-dependency `HashingEmbeddingModel`; plug in your own model via the `EmbeddingModel` interface.
- **Vector store** — index and similarity-search those vectors. Ships with `InMemoryVectorStore` (brute-force cosine, JSON-persistable).
- **Generation** — produce a grounded answer with any `LanguageModel` you supply (an on-device LLM such as `flutter_gemma`, or a remote API).

## Why on-device?

Keeping retrieval and embeddings on the device means user data never leaves the phone, the app works offline, and there are no per-query API costs. You only need a network call if you choose a remote `LanguageModel`.

## Install

```yaml
dependencies:
  on_device_rag: ^0.1.0
```

## Quick start

```dart
import 'package:on_device_rag/on_device_rag.dart';

final engine = RagEngine(
  embeddingModel: HashingEmbeddingModel(dimensions: 256),
  vectorStore: InMemoryVectorStore(),
  // languageModel: MyGemmaModel(), // optional — needed only for ask()
);

// Index knowledge (long text is chunked automatically).
await engine.index('Flutter is a UI toolkit by Google. Dart is its language.');

// Retrieve relevant context (no LLM required).
final hits = await engine.retrieve('What language does Flutter use?', topK: 2);

// Or, with a LanguageModel, get a grounded streamed answer:
// final result = await engine.ask('What language does Flutter use?');
// await for (final token in result.answer) stdout.write(token);
```

## Plugging in your own pieces

Every part is an interface:

```dart
class MyEmbedder implements EmbeddingModel { /* ... */ }
class MyStore    implements VectorStore    { /* ... */ }
class MyLlm      implements LanguageModel  { /* ... */ }
```

Pass them to `RagEngine` and the orchestration stays the same.

## Persistence

`InMemoryVectorStore` serialises to JSON so you can save the index anywhere:

```dart
final json = store.toJson();          // write to a file / prefs / db
final restored = InMemoryVectorStore.fromJson(json);
```

## How it works

`index()` cleans and chunks text, embeds each chunk, and adds the embedded chunks to the store. `ask()` embeds the question, runs a cosine-similarity search for the top-K chunks, builds a grounded prompt (answer **only** from the supplied context), and streams the answer from your `LanguageModel`. The default `HashingEmbeddingModel` uses the feature-hashing ("hashing trick") of word and character tri-gram features, so it needs no model file and is fully deterministic — great for tests and small corpora. For higher semantic quality, plug in a real embedding model behind the same interface.

## License

MIT

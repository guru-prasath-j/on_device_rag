# Changelog

## 0.2.0

The README examples now run as written: the engine gained the convenience API
they describe, plus metadata filtering, deletion and diversity re-ranking.

### Added
* `RagEngine` parts are all optional: embeddings default to
  `HashingEmbeddingModel`, storage to `InMemoryVectorStore`.
* `addDocument(id:, text:, metadata:)` (replaces an existing id),
  `removeDocument(id)` and `clear()`.
* `query()` returns a `RagAnswer` with the full text, sources, scores and
  prompt; `queryStream()` yields answer tokens for chat UIs.
* `topK` default on the engine; per-call `topK`, `minScore`, `where`
  metadata filter and `diversity` (Maximal Marginal Relevance) on `retrieve`,
  `retrieveScored`, `ask`, `query` and `queryStream`.
* `RagResult.prompt` and `RagResult.scores`.
* `PromptBuilder(maxContextChars:, sourceKey:)` keeps prompts inside small
  context windows and labels chunks with their source; `defaultTemplate` is
  public.
* `VectorMath.maximalMarginalRelevance`.
* `InMemoryVectorStore.documents`, cached norms for faster search.
* `TextChunker(splitOnBoundaries:)`: chunks now end at sentence or word
  boundaries by default instead of mid-word.
* `HashingEmbeddingModel`: `ngramSize`, `ngramWeight`, `embedSync`,
  `tokenize` and `fnv1a32`.
* Each indexed chunk records its position under `metadata['chunkIndex']`.

### Fixed
* `HashingEmbeddingModel` used `String.hashCode`, which differs between
  platforms and SDK versions, so a persisted index could silently stop
  matching after an app update or on the web. It now uses a stable FNV-1a hash.
* `HashingEmbeddingModel` dropped every non-ASCII character, so text in most
  languages produced empty vectors. Tokenisation is now Unicode-aware.
* Examples and README used an API that did not exist.
* Shortened the pubspec description to fit pub.dev's 60–180 character limit.

### Breaking
* `VectorStore` gained `removeWhere` and a `where` parameter on `search`;
  custom stores must implement them.
* Embeddings from `HashingEmbeddingModel` changed. Re-index any persisted
  `InMemoryVectorStore` JSON built with 0.1.0.

## 0.1.0

- Initial release.
- `RagEngine` orchestrator with `index`, `retrieve` and `ask`.
- `TextChunker` for overlapping character-window chunking.
- `EmbeddingModel` interface plus zero-dependency `HashingEmbeddingModel`.
- `VectorStore` interface plus `InMemoryVectorStore` with JSON persistence.
- `LanguageModel` interface for pluggable on-device or remote generation.
- `PromptBuilder` with a grounded default template and `VectorMath` helpers.

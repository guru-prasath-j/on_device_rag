# Changelog

## 0.1.0

- Initial release.
- `RagEngine` orchestrator with `index`, `retrieve` and `ask`.
- `TextChunker` for overlapping character-window chunking.
- `EmbeddingModel` interface plus zero-dependency `HashingEmbeddingModel`.
- `VectorStore` interface plus `InMemoryVectorStore` with JSON persistence.
- `LanguageModel` interface for pluggable on-device or remote generation.
- `PromptBuilder` with a grounded default template and `VectorMath` helpers.

/// A lightweight, pure-Dart retrieval-augmented-generation (RAG) engine that
/// runs entirely on-device.
///
/// The package gives you chunking, embeddings, a vector store and grounded
/// prompt assembly out of the box, with pluggable interfaces so you can swap in
/// your own embedding model, vector store or language model. The default
/// [HashingEmbeddingModel] has zero native dependencies, so the package works
/// on every Flutter and Dart platform.
library on_device_rag;

export 'src/chunking/text_chunker.dart';
export 'src/embedding/embedding_model.dart';
export 'src/embedding/hashing_embedding_model.dart';
export 'src/llm/language_model.dart';
export 'src/math/vector_math.dart';
export 'src/models/rag_document.dart';
export 'src/rag/prompt_builder.dart';
export 'src/rag/rag_engine.dart';
export 'src/rag/rag_result.dart';
export 'src/store/in_memory_vector_store.dart';
export 'src/store/vector_store.dart';

/// A minimal interface for the text-generation model that produces the final
/// answer in a RAG pipeline.
///
/// The package is model-agnostic: implement this with an on-device model (for
/// example via the `flutter_gemma` plugin) or a remote API. The engine only
/// needs a way to turn a fully-built prompt into streamed text.
abstract interface class LanguageModel {
  /// Generates a completion for [prompt], yielding text incrementally.
  ///
  /// Implementations that cannot stream may yield the whole answer as a single
  /// event.
  Stream<String> generate(String prompt);
}

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

/// Adapts a plain function to [LanguageModel], so any on-device runtime, SDK
/// or HTTP client can power the engine without writing a class.
///
/// ```dart
/// final engine = RagEngine(
///   languageModel: FunctionLanguageModel.fromFuture(
///     (prompt) => myClient.complete(prompt),
///   ),
/// );
/// ```
class FunctionLanguageModel implements LanguageModel {
  /// Wraps a function that streams the answer for a prompt.
  const FunctionLanguageModel(this._generate);

  /// Wraps a function that returns the whole answer at once. The answer is
  /// emitted as a single stream event.
  factory FunctionLanguageModel.fromFuture(
    Future<String> Function(String prompt) complete,
  ) {
    Stream<String> run(String p) => Stream.fromFuture(complete(p));
    return FunctionLanguageModel(run);
  }

  final Stream<String> Function(String prompt) _generate;

  @override
  Stream<String> generate(String prompt) => _generate(prompt);
}

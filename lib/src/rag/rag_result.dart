import '../models/rag_document.dart';

/// The outcome of `RagEngine.ask`: a streamed [answer] plus the [sources] that
/// grounded it.
class RagResult {
  /// Creates a result.
  const RagResult({
    required this.answer,
    required this.sources,
    this.prompt,
    this.scores = const [],
  });

  /// The answer text, streamed token-by-token as the model produces it.
  final Stream<String> answer;

  /// The context documents retrieved for the question, in ranked order.
  final List<RagDocument> sources;

  /// The exact prompt sent to the language model, if recorded.
  final String? prompt;

  /// Similarity scores for [sources], in the same order (may be empty).
  final List<double> scores;
}

/// The outcome of `RagEngine.query`: the complete [answer] text plus the
/// [sources] that grounded it.
class RagAnswer {
  /// Creates an answer.
  const RagAnswer({
    required this.answer,
    required this.sources,
    required this.prompt,
    this.scores = const [],
  });

  /// The full generated answer.
  final String answer;

  /// The context documents retrieved for the question, in ranked order.
  final List<RagDocument> sources;

  /// The exact prompt sent to the language model.
  final String prompt;

  /// Similarity scores for [sources], in the same order.
  final List<double> scores;

  /// The distinct `documentId`s of [sources], for "cited from" UIs.
  List<String> get sourceDocumentIds => [
        for (final id in {
          for (final s in sources)
            if (s.metadata['documentId'] is String)
              s.metadata['documentId']! as String,
        })
          id,
      ];

  @override
  String toString() => answer;
}

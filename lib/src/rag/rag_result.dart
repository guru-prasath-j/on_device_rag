import '../models/rag_document.dart';

/// The outcome of [RagEngine.ask]: a streamed [answer] plus the [sources] that
/// grounded it.
class RagResult {
  /// Creates a result.
  const RagResult({required this.answer, required this.sources});

  /// The answer text, streamed token-by-token as the model produces it.
  final Stream<String> answer;

  /// The context documents retrieved for the question, in ranked order.
  final List<RagDocument> sources;
}

import '../models/rag_document.dart';

/// Builds a grounded prompt from a question and the retrieved context.
///
/// The default template instructs the model to answer using only the supplied
/// context and to admit when the answer is not present, which is the core
/// mechanism RAG uses to reduce hallucination. Provide a custom [template] to
/// change the instructions; the placeholders `{context}` and `{question}` are
/// substituted.
class PromptBuilder {
  /// Creates a prompt builder.
  ///
  /// [template] must contain `{context}` and `{question}`. If
  /// [maxContextChars] is set, context chunks are added in ranked order until
  /// the budget is reached, keeping prompts inside small on-device context
  /// windows. If [sourceKey] is set, each chunk is labelled with that metadata
  /// value (for example the file name) so the model can cite it.
  const PromptBuilder({
    this.template = defaultTemplate,
    this.maxContextChars,
    this.sourceKey,
  });

  /// The built-in grounded template.
  static const String defaultTemplate = '''
You are a helpful assistant. Answer the question using ONLY the context below.
If the answer is not contained in the context, say you don't have enough
information.

Context:
{context}

Question: {question}

Answer:''';

  /// The prompt template containing `{context}` and `{question}` placeholders.
  final String template;

  /// Maximum total characters of context to include, or `null` for no limit.
  final int? maxContextChars;

  /// Metadata key whose value labels each context chunk, e.g. `'source'`.
  final String? sourceKey;

  /// Builds the final prompt string from [question] and [context] documents.
  String build(String question, List<RagDocument> context) {
    final parts = <String>[];
    var used = 0;
    for (final doc in context) {
      final label = sourceKey == null ? null : doc.metadata[sourceKey];
      final entry = '[${parts.length + 1}]'
          '${label == null ? '' : ' ($label)'} ${doc.text}';
      final budget = maxContextChars;
      if (budget != null && parts.isNotEmpty && used + entry.length > budget) {
        break;
      }
      parts.add(entry);
      used += entry.length;
    }
    final ctx = parts.isEmpty ? 'No relevant context found.' : parts.join('\n\n');
    return template
        .replaceAll('{context}', ctx)
        .replaceAll('{question}', question);
  }
}

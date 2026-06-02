import '../models/rag_document.dart';

/// Builds a grounded prompt from a question and the retrieved context.
///
/// The default template instructs the model to answer using only the supplied
/// context and to admit when the answer is not present, which is the core
/// mechanism RAG uses to reduce hallucination. Provide a custom [template] to
/// change the instructions; the placeholders `{context}` and `{question}` are
/// substituted.
class PromptBuilder {
  /// Creates a prompt builder with an optional custom [template].
  const PromptBuilder({this.template = _defaultTemplate});

  /// The prompt template containing `{context}` and `{question}` placeholders.
  final String template;

  static const String _defaultTemplate = '''
You are a helpful assistant. Answer the question using ONLY the context below.
If the answer is not contained in the context, say you don't have enough
information.

Context:
{context}

Question: {question}

Answer:''';

  /// Builds the final prompt string from [question] and [context] documents.
  String build(String question, List<RagDocument> context) {
    final ctx = context.isEmpty
        ? 'No relevant context found.'
        : context
            .asMap()
            .entries
            .map((e) => '[${e.key + 1}] ${e.value.text}')
            .join('\n\n');
    return template
        .replaceAll('{context}', ctx)
        .replaceAll('{question}', question);
  }
}

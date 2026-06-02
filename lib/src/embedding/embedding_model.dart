/// Turns text into a fixed-length numeric vector so that the semantic or
/// lexical closeness of two pieces of text can be measured as the distance
/// between their vectors.
///
/// Implement this interface to plug in any embedder — a local quantised model,
/// a remote embedding API, or the bundled [HashingEmbeddingModel].
abstract class EmbeddingModel {
  /// Const base constructor for subclasses.
  const EmbeddingModel();

  /// The dimensionality of the vectors produced by [embed].
  int get dimensions;

  /// Embeds a single [text] into a vector of length [dimensions].
  Future<List<double>> embed(String text);

  /// Embeds a batch of [texts]. Defaults to mapping [embed] over the list, but
  /// implementations backed by a model should override this for efficiency.
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final out = <List<double>>[];
    for (final t in texts) {
      out.add(await embed(t));
    }
    return out;
  }
}

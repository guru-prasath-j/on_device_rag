/// Splits long text into overlapping, retrieval-friendly chunks.
///
/// Chunking matters for two reasons: a whole document rarely fits in an LLM's
/// context window, and retrieval is sharper when each indexed unit is small and
/// topically focused. The [overlap] keeps sentences that straddle a boundary
/// from being lost between chunks.
class TextChunker {
  /// Creates a chunker.
  ///
  /// [chunkSize] is the maximum number of characters per chunk and [overlap] is
  /// how many trailing characters are repeated at the start of the next chunk.
  /// [overlap] must be smaller than [chunkSize].
  const TextChunker({this.chunkSize = 600, this.overlap = 100})
      : assert(chunkSize > 0, 'chunkSize must be positive'),
        assert(overlap >= 0 && overlap < chunkSize,
            'overlap must be in [0, chunkSize)',);

  /// Maximum characters per chunk.
  final int chunkSize;

  /// Characters repeated between consecutive chunks.
  final int overlap;

  /// Splits [text] into chunks, collapsing runs of whitespace first.
  ///
  /// Returns an empty list for blank input, and a single chunk when the
  /// cleaned text already fits within [chunkSize].
  List<String> chunk(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return const [];
    if (clean.length <= chunkSize) return [clean];

    final step = chunkSize - overlap;
    final chunks = <String>[];
    var start = 0;
    while (start < clean.length) {
      final end = start + chunkSize < clean.length
          ? start + chunkSize
          : clean.length;
      chunks.add(clean.substring(start, end));
      if (end == clean.length) break;
      start += step;
    }
    return chunks;
  }
}

/// Splits long text into overlapping, retrieval-friendly chunks.
///
/// Chunking matters for two reasons: a whole document rarely fits in an LLM's
/// context window, and retrieval is sharper when each indexed unit is small and
/// topically focused. The [overlap] keeps sentences that straddle a boundary
/// from being lost between chunks.
///
/// With [splitOnBoundaries] (the default) chunks end at a sentence end or,
/// failing that, a word break, and the overlap starts on a word, so no chunk
/// begins or ends mid-word.
///
/// With [preserveParagraphs], paragraphs (separated by blank lines) are kept
/// whole and packed together up to [chunkSize]; only paragraphs longer than
/// [chunkSize] are split. This keeps headings, list items and Markdown
/// sections intact, which usually retrieves better for structured documents.
class TextChunker {
  /// Creates a chunker.
  ///
  /// [chunkSize] is the maximum number of characters per chunk and [overlap] is
  /// how many trailing characters are repeated at the start of the next chunk.
  /// [overlap] must be smaller than [chunkSize].
  const TextChunker({
    this.chunkSize = 600,
    this.overlap = 100,
    this.splitOnBoundaries = true,
    this.preserveParagraphs = false,
  })  : assert(chunkSize > 0, 'chunkSize must be positive'),
        assert(
          overlap >= 0 && overlap < chunkSize,
          'overlap must be in [0, chunkSize)',
        );

  /// Maximum characters per chunk.
  final int chunkSize;

  /// Characters repeated between consecutive chunks.
  final int overlap;

  /// Whether to cut at sentence and word boundaries instead of exactly every
  /// [chunkSize] characters.
  final bool splitOnBoundaries;

  /// Whether to keep paragraphs (text separated by a blank line) together,
  /// joining packed paragraphs with a blank line. Paragraph-packed chunks do
  /// not overlap; [overlap] still applies inside oversized paragraphs.
  final bool preserveParagraphs;

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _paragraphBreak = RegExp(r'\n\s*\n');

  /// Splits [text] into chunks, collapsing runs of whitespace first.
  ///
  /// Returns an empty list for blank input, and a single chunk when the
  /// cleaned text already fits within [chunkSize]. Every chunk is at most
  /// [chunkSize] characters long.
  ///
  /// With [preserveParagraphs], whitespace is collapsed within each paragraph
  /// and paragraphs are separated by a blank line.
  List<String> chunk(String text) {
    if (preserveParagraphs) return _chunkParagraphs(text);
    return _chunkFlat(text);
  }

  List<String> _chunkParagraphs(String text) {
    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final raw in text.split(_paragraphBreak)) {
      final paragraph = raw.replaceAll(_whitespace, ' ').trim();
      if (paragraph.isEmpty) continue;
      if (paragraph.length > chunkSize) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
        chunks.addAll(_chunkFlat(paragraph));
        continue;
      }
      final joined = buffer.length + 2 + paragraph.length;
      if (buffer.isNotEmpty && joined > chunkSize) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(paragraph);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());
    return chunks;
  }

  List<String> _chunkFlat(String text) {
    final clean = text.replaceAll(_whitespace, ' ').trim();
    if (clean.isEmpty) return const [];
    if (clean.length <= chunkSize) return [clean];

    final chunks = <String>[];
    var start = 0;
    while (start < clean.length) {
      var end =
          start + chunkSize < clean.length ? start + chunkSize : clean.length;
      if (splitOnBoundaries && end < clean.length) {
        end = _boundaryBefore(clean, start, end);
      }
      final piece = clean.substring(start, end).trim();
      if (piece.isNotEmpty) chunks.add(piece);
      if (end >= clean.length) break;

      var next = end - overlap;
      if (splitOnBoundaries && overlap > 0) {
        next = _wordStartFrom(clean, next, end);
      }
      start = next > start ? next : end;
    }
    return chunks;
  }

  /// Latest good cut point in `(start + chunkSize/2, end]`.
  int _boundaryBefore(String s, int start, int end) {
    final floor = start + chunkSize ~/ 2;
    for (var i = end; i > floor; i--) {
      final c = s.codeUnitAt(i - 1);
      final atSentenceEnd = c == 0x2E /* . */ ||
          c == 0x21 /* ! */ ||
          c == 0x3F /* ? */ ||
          c == 0x3002 /* 。 */ ||
          c == 0x0964; /* । */
      if (atSentenceEnd && s.codeUnitAt(i) == 0x20) return i;
    }
    for (var i = end; i > floor; i--) {
      if (s.codeUnitAt(i) == 0x20) return i;
    }
    return end;
  }

  /// First word start at or after [pos], but before [limit].
  int _wordStartFrom(String s, int pos, int limit) {
    if (pos <= 0) return 0;
    for (var i = pos; i < limit; i++) {
      if (s.codeUnitAt(i - 1) == 0x20) return i;
    }
    return pos;
  }
}

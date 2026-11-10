/// Fixes that belong to the *characters* and the *line wrapping* of an exam
/// text, before anyone looks for question numbers or alternatives.
///
/// PDF text layers and OCR agree on the words but disagree on the code points
/// used to write them: a font may store "ﬁ" as one ligature, a scanned page may
/// read a right single quote as an apostrophe, and a narrow column breaks a
/// sentence every eight words. Each of those costs a question later, because a
/// marker split over two lines is no longer a marker for any regular expression.
class ExamTextNormalizer {
  const ExamTextNormalizer._();

  /// `parsePages` marks page starts with `\u0000PROVA_SOCIAL_PAGE_n\u0000`, so
  /// the sentinel has to survive every cleaning step below.
  static const pageSentinel = '\u0000';

  static const _ligatures = {
    'ﬀ': 'ff',
    'ﬁ': 'fi',
    'ﬂ': 'fl',
    'ﬃ': 'ffi',
    'ﬄ': 'ffl',
    'ﬅ': 'st',
    'ﬆ': 'st',
    'Ĳ': 'IJ',
    'ĳ': 'ij',
    'œ': 'oe',
    'Œ': 'OE',
    'Æ': 'AE',
    'æ': 'ae',
  };

  static const _quotes = {
    '‘': "'",
    '’': "'",
    '‚': "'",
    '‛': "'",
    '“': '"',
    '”': '"',
    '„': '"',
    '…': '...',
    '™': 'TM',
  };

  static const _dashes = {
    '‐': '-',
    '‑': '-',
    '‒': '-',
    '–': '-',
    '—': '-',
    '―': '-',
    '−': '-',
    '➖': '-',
  };

  /// Space-like code points become a plain space; the invisible joiners that a
  /// typesetter leaves inside a word disappear with it.
  static final RegExp _spaces = RegExp(
    '[\u00a0\u2007\u202f\u2009\u200a\u2002\u2003\u2004\u2005\u2006]',
  );

  static final RegExp _invisible = RegExp('[\u200b\u200c\u200d\u2060\ufeff]');

  /// Everything below C0 that is not a line break, a tab or the page sentinel.
  static final RegExp _control = RegExp(
    '[\u0001-\u0008\u000b\f\u000e-\u001f\u007f]',
  );

  static final RegExp _multipleBlankLines = RegExp(r'\n{3,}');

  /// A line that opens with a marker of its own starts a new block: never glue
  /// it to the line above, because it is a question number, an alternative, a
  /// list item or the page sentinel.
  ///
  /// A number alone is not enough to be a marker. Columns break mid-sentence in
  /// front of a measurement — “sobre uma pista circular de / 300 m de diâme-
  /// tro.” — and treating that as a block start invents a question numbered 300
  /// and loses the one printed above it. A number opens a block when it carries
  /// marker punctuation, stands alone on the line, or is followed by a
  /// capitalised word, which is how the boards write “67 Ontem, três atletas…”.
  static final List<RegExp> _blockStarts = [
    RegExp(r'^\s*[\(\[]\s*\w\s*[\)\].:]'),
    RegExp(r'^\s*[A-Ha-h][)\].:]'),
    RegExp(r'^\s*\d{1,4}\s*[.)\-–—:º°]'),
    RegExp(r'^\s*\d{1,4}\s*$'),
    RegExp(r'^\s*\d{1,4}\s+[A-ZÀ-Ú](?:\s|[.)\-–—:])'),
    RegExp(r'^\s*\d{1,4}\s+(?:[A-ZÀ-Ú][A-ZÀ-Úa-zà-ÿ]|\()'),
    // “39 a 41.” is the heading of a language track, not the tail of the
    // sentence printed above it.
    RegExp(r'^\s*\d{1,4}\s+(?:a|até|to|through|y|e)\s+\d{1,4}\s*[.:)]?$'),
    RegExp(r'^\s*[•\-*]'),
    RegExp(r'^\u0000'),
    RegExp(r'^\s*quest\s*$', caseSensitive: false),
    RegExp(
      r'^\s*(?:quest[ãa]o|item|proposta|reda[çc][ãa]o|resposta|colunas?)\b',
      caseSensitive: false,
    ),
  ];

  /// A block that is nothing but a marker cannot be the tail of a sentence.
  static final RegExp _bareMarker = RegExp(
    r'^\s*(?:[\(\[]?(?:[A-Ha-h]|\d{1,3})[\)\].:]?'
    r'|\d{1,3}\s*[ªº°])\s*$',
  );

  static final RegExp _sentenceEnd = RegExp(r'''[.!?;:]["')\]]?\s*$''');

  /// A line in capitals is a heading or a section name, not the tail of
  /// the sentence above it.
  static final RegExp _upperCaseLine = RegExp(r'^[^a-zà-öø-ÿ]{3,}$');

  /// Some cadernos, the ENEM ones above all, kern one syllable of “Questão” so
  /// far from the stem that the text layer returns “Quest ão 01”. The marker is
  /// what every rule downstream greps for, so it is rebuilt here. Prose keeps
  /// its spaces: only the stem “quest” followed by a floating syllable joins.
  static final RegExp _splitMarkerWord = RegExp(
    r'\b([Qq]uest)[ \t]+([ÃãAa][Oo]|[ÕõOo][Ee][Ss]|[Oo][Ee][Ss]|[Aa][Oo])\b',
  );

  /// Two-column extraction can reverse the tail of “Questão 180” at the
  /// column boundary, yielding “ão 180 Quest”. Rebuild that marker before
  /// block joining so the final question is not swallowed by the answer sheet.
  static final RegExp _reversedQuestionMarker = RegExp(
    r'\b[ãa]o\s+(\d{1,3})\s+Quest\b',
    caseSensitive: false,
  );

  static String normalize(String source) {
    var text = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll('\u2028', '\n').replaceAll('\u2029', '\n');
    for (final entry in {..._ligatures, ..._quotes, ..._dashes}.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    // A soft hyphen is an instruction to the typesetter, never content.
    text = text.replaceAll('\u00ad', '');
    text = text.replaceAll(_invisible, '');
    text = text.replaceAll(_spaces, ' ');
    text = text.replaceAll(_control, '');
    text = text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trimRight())
        .join('\n');
    text = text.replaceAllMapped(_splitMarkerWord, _joinSplitMarkerWord);
    text = text.replaceAllMapped(
      _reversedQuestionMarker,
      (match) => 'Questão ${match.group(1)}',
    );
    text = _unwrapLines(text)
        .replaceAllMapped(_splitMarkerWord, _joinSplitMarkerWord);
    return text.replaceAll(_multipleBlankLines, '\n\n');
  }

  static String _joinSplitMarkerWord(Match match) {
    final head = match.group(1)!;
    var joined = match.group(2)!.toLowerCase().endsWith('o') ? 'ão' : 'ões';
    if (head == head.toUpperCase()) joined = joined.toUpperCase();
    return '$head$joined';
  }

  /// Reassembles the blocks a narrow column broke.
  ///
  /// Wrapping is joined with a space, except after a hyphen, where the sign and
  /// the fragment that follows it rebuild one word. A blank line, a marker or a
  /// completed sentence always ends a block, so question numbers and the
  /// alternatives stay on their own lines.
  static String _unwrapLines(String text) {
    final source = text.split('\n');
    final blocks = <String>[];
    var buffer = '';
    var open = false;
    for (var index = 0; index < source.length; index++) {
      final raw = source[index];
      final line = raw.trim();
      if (line.isEmpty) {
        if (open) {
          blocks.add(buffer);
          buffer = '';
          open = false;
        }
        blocks.add('');
        continue;
      }
      if (line.contains(pageSentinel)) {
        if (open) {
          blocks.add(buffer);
          buffer = '';
          open = false;
        }
        blocks.add(line);
        continue;
      }
      if (!open) {
        buffer = line;
        open = true;
        continue;
      }
      final hyphen = _brokenEnd(buffer);
      if (hyphen != null) {
        final head = _leadingFragment(line);
        if (head != null) {
          buffer = '${buffer.substring(0, hyphen)}$head';
          final rest = line.substring(line.indexOf(head) + head.length).trim();
          if (rest.isNotEmpty) buffer = '$buffer $rest';
          continue;
        }
      }
      if (_continues(buffer, line, source, index)) {
        buffer = '$buffer $line';
        continue;
      }
      blocks.add(buffer);
      buffer = line;
    }
    if (open) blocks.add(buffer);
    return blocks.join('\n');
  }

  static bool _continues(
    String buffer,
    String line,
    List<String> source,
    int index,
  ) {
    if (_isBlockStart(line) || _bareMarker.hasMatch(buffer)) return false;
    if (_startsOptionRun(source, index)) return false;
    if (_upperCaseLine.hasMatch(line)) return false;
    // A heading does not swallow the sentence printed under it either.
    if (_upperCaseLine.hasMatch(buffer)) return false;
    // A finished sentence starts a new block; a column that wrapped mid-word
    // keeps no punctuation at the break and stays open.
    return !_sentenceEnd.hasMatch(buffer);
  }

  static final RegExp _bareOption = RegExp(r'^\s*([A-Ha-h])\s+\S');

  /// “A denunciar …” / “B descrever …” / “C valorizar …”: the ENEM and a few
  /// other boards print the alternative letter with no punctuation at all, so
  /// the line looks like the continuation of the stem above it. Two further
  /// letters in order prove it is a list, and the list keeps its lines apart.
  static bool _startsOptionRun(List<String> source, int index) {
    final first = _bareOption.firstMatch(source[index].trim());
    if (first == null) return false;
    var letter = first.group(1)!.toUpperCase().codeUnitAt(0);
    var run = 1;
    for (var i = index + 1; i < source.length && run < 3; i++) {
      final line = source[i].trim();
      if (line.isEmpty) break;
      final match = _bareOption.firstMatch(line);
      if (match == null) break;
      final next = match.group(1)!.toUpperCase().codeUnitAt(0);
      if (next != letter + 1) break;
      letter = next;
      run++;
    }
    return run >= 3;
  }

  static bool _isBlockStart(String line) =>
      _blockStarts.any((start) => start.hasMatch(line));

  /// The offset of the hyphen that ends a line, or null when the line does not
  /// break a word. A justified PDF usually leaves a space after the sign.
  static int? _brokenEnd(String line) {
    var end = line.length;
    while (end > 0 && (line[end - 1] == ' ' || line[end - 1] == '\t')) {
      end--;
    }
    if (end < 3 || line[end - 1] != '-') return null;
    if (!_isLetter(line[end - 2])) return null;
    return end - 1;
  }

  /// The rest of the word the previous line broke: the first fragment of the
  /// line, and only when it continues it in lower case. A capital starts a new
  /// sentence and a digit is a split number, so both stay where they are.
  static String? _leadingFragment(String line) {
    final space = line.indexOf(' ');
    final head = space < 0 ? line : line.substring(0, space);
    if (head.isEmpty) return null;
    final char = head[0];
    if (!_isLetter(char) || char != char.toLowerCase()) return null;
    return head;
  }

  static bool _isLetter(String char) =>
      char.isNotEmpty && RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(char);
}

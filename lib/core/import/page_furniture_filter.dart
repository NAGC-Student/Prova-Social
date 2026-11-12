import 'text_normalizer.dart';

/// Removes the page furniture — running headers, footers, watermarks and page
/// numbers — without knowing which board printed the exam.
///
/// Listing the strings of one board is how an importer ends up working for a
/// single PDF. The evidence that a line is furniture is that the same line
/// keeps returning to the edge of page after page, or that a slot carries a
/// running count. Both signals are measured across the whole document, so a
/// question number that happens to open a column survives.
class PageFurnitureReport {
  const PageFurnitureReport({required this.pages, required this.removedLines});

  final List<String> pages;

  /// Distinct texts that were dropped, for the import report.
  final List<String> removedLines;

  bool get removedAnything => removedLines.isNotEmpty;
}

class _Edge {
  const _Edge({required this.index, required this.slot});

  final int index;

  /// Which edge of the page the line is, counted over non-empty lines:
  /// `top0`, `top1`, `bottom0` (the last line), and so on.
  final String slot;
}

class _SlotNumber {
  const _SlotNumber({required this.page, required this.value});

  final int page;
  final int value;
}

class PageFurnitureFilter {
  const PageFurnitureFilter({this.edgeLines = 3, this.minimumShare = .5});

  final int edgeLines;
  final double minimumShare;

  /// At most this many copies of one line per page still looks like a header
  /// printed once per column; a line that repeats ten times on a page is the
  /// answer grid of a true/false exam, not decoration.
  static const maximumCopiesPerPage = 2;

  static final RegExp _pageNumberWord = RegExp(
    r'^[\s\-–—:]*(?:p[áa]gina|pag\.?|page|fl\.?|folha)\s*\d{1,4}'
    r'(?:\s*(?:de|/|dos?|das)\s*\d{1,4})?[\s).:]*$',
    caseSensitive: false,
  );

  static final RegExp _numberedPair = RegExp(
    r'^[\s\-–—:]*\d{1,4}\s*(?:de|/|dos?|das)\s*\d{1,4}[\s).:]*$',
  );

  static final RegExp _bareNumber = RegExp(r'^[\s\-–—:]*\d{1,4}[\s).:]*$');

  /// A line that starts a question or an item is content, never furniture,
  /// however regularly it lands on a page edge.
  static final RegExp _questionLabel = RegExp(
    r'^(?:quest(?:[ãa]o|[õo]es)?\b|q(?:uest[ãa]o)?\.?\s*\d|item\s|quest\.|question)',
    caseSensitive: false,
  );

  static final RegExp _digits = RegExp(r'\d+');
  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _letters = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]');

  /// A security watermark (“ENEM2025ENEM2025…”) is one token printed over and
  /// over across the sheet. It never sits at a page edge, so it needs its own
  /// rule: the same word three times and nothing else on the line.
  static final RegExp _repeatedToken = RegExp(
    r'^([A-Za-z0-9À-ÿ.\-]{3,24})[ \t]*(?:\1[ \t]*){2,}$',
  );

  /// Print stamps and export timestamps carry no words at all.
  static final RegExp _dateStamp = RegExp(
    r'^\W*\d{1,2}[./-]\d{1,2}[./-]\d{2,4}(\s+\d{1,2}:\d{2}(:\d{2})?)?\W*$',
  );

  static final RegExp _timeStamp = RegExp(r'^\W*\d{1,2}:\d{2}(:\d{2})?\W*$');

  /// A candidate code (“*010175AZ1*”) is a short run of digits and letters with
  /// no space in it, so the letter count of a normal header would never see it.
  static final RegExp _codeToken = RegExp(r'^[A-Za-z0-9À-ÿ._\-*/]{8,24}$');

  /// Known exam watermark tokens that boards tile across pages (ENEM, year, board name).
  /// These appear as short repeated lines and should be stripped wherever they appear.
  static final Set<String> _knownWatermarkTokens = {
    'ENEM',
    'INEP',
    'ENCCEJA',
    'ENEM2022',
    'ENEM2023',
    'ENEM2024',
    'ENEM2025',
    '2022',
    '2023',
    '2024',
    '2025',
  };

  /// [footers] carries, per page, the line indexes the PDF placed in the bottom
  /// band of the sheet. Where those coordinates exist, they decide what can be
  /// a page number; without them the filter falls back to the last lines of the
  /// text, which is only good enough for a repeated header.
  PageFurnitureReport apply(
    Iterable<String> pages, {
    List<Set<int>> footers = const [],
  }) {
    final pageLines = pages
        .map((page) => page.split('\n').toList(growable: true))
        .toList(growable: false);
    if (pageLines.isEmpty) {
      return const PageFurnitureReport(pages: [], removedLines: []);
    }
    final pageCount = pageLines.length;
    Set<int> footerOf(int page) =>
        page < footers.length ? footers[page] : const <int>{};

    final headerPages = <String, int>{};
    final maskedPages = <String, int>{};
    final numberSlots = <String, List<_SlotNumber>>{};

    for (var page = 0; page < pageCount; page++) {
      final lines = pageLines[page];
      final edges = _edges(lines, footer: footerOf(page));
      if (edges.isEmpty) continue;
      final copies = <String, int>{};
      final maskedCopies = <String, int>{};
      final stampMasks = <String>{};
      for (var index = 0; index < lines.length; index++) {
        final text = _signature(lines[index]);
        if (text.isEmpty || _isSentinel(text)) continue;
        copies[text] = (copies[text] ?? 0) + 1;
        final mask = _masked(text);
        if (mask != null) maskedCopies[mask] = (maskedCopies[mask] ?? 0) + 1;
        if (mask != null && _isCodeStamp(text)) stampMasks.add(mask);
      }
      final counted = <String>{};
      for (final edge in edges) {
        final text = _signature(lines[edge.index]);
        if (text.isEmpty || _isSentinel(text)) continue;
        final count = copies[text] ?? 0;
        if (text.length >= 4 &&
            text.length <= 80 &&
            count <= maximumCopiesPerPage) {
          headerPages[text] = (headerPages[text] ?? 0) + 1;
        }
        final mask = _masked(text);
        if (mask != null && (maskedCopies[mask] ?? 0) <= maximumCopiesPerPage) {
          maskedPages[mask] = (maskedPages[mask] ?? 0) + 1;
          counted.add(mask);
        }
        final value = _pageNumberValue(text, edge.slot);
        if (value != null) {
          numberSlots
              .putIfAbsent(edge.slot, () => <_SlotNumber>[])
              .add(_SlotNumber(page: page, value: value));
        }
      }
      // A candidate code sits in the middle of the sheet, where the edge scan
      // never reaches it. Its evidence is the same shape on almost every page.
      for (final mask in stampMasks.difference(counted)) {
        maskedPages[mask] = (maskedPages[mask] ?? 0) + 1;
      }
    }

    final headerFloor = pageCount < 2 ? 3 : (pageCount * minimumShare).ceil();
    final maskedFloor = pageCount < 2 ? 3 : (pageCount * .8).ceil();
    final headers = <String>{
      for (final entry in headerPages.entries)
        if (entry.value >= headerFloor) entry.key,
    };
    final masks = <String>{
      for (final entry in maskedPages.entries)
        if (entry.value >= maskedFloor) entry.key,
    };
    final pageOffsets = <String, int>{};
    numberSlots.forEach((slot, samples) {
      final offset = _pageOffset(samples, pageCount);
      if (offset != null) pageOffsets[slot] = offset;
    });

    final removed = <String>[];
    final removedSeen = <String>{};

    for (var page = 0; page < pageCount; page++) {
      final lines = pageLines[page];
      final edgeSlots = <int, String>{
        for (final edge in _edges(lines, footer: footerOf(page)))
          edge.index: edge.slot,
      };
      for (var index = 0; index < lines.length; index++) {
        final original = lines[index];
        final text = _signature(original);
        if (text.isEmpty || _isSentinel(text)) continue;
        if (_isAlwaysDecoration(text)) {
          lines[index] = '';
          if (removedSeen.add(text)) removed.add(original.trim());
          continue;
        }
        // Remove known watermark tokens (ENEM, year, board name) that are
        // tiled across the page as short lines.
        final trimmed = original.trim();
        if (_knownWatermarkTokens.contains(trimmed.toUpperCase())) {
          lines[index] = '';
          if (removedSeen.add(text)) removed.add(trimmed);
          continue;
        }
        // Only the number itself is furniture: a corroborated slot does not
        // give permission to delete other content that landed there.
        final slot = edgeSlots[index];
        final isPageNumber =
            slot != null &&
            _isPageNumberInSlot(text, slot, page, pageOffsets[slot]);
        final isHeader = headers.contains(text);
        final mask = isHeader ? null : _masked(text);
        final isMaskedHeader = mask != null && masks.contains(mask);
        if (!isPageNumber && !isHeader && !isMaskedHeader) continue;
        if (!isPageNumber && _questionLabel.hasMatch(text)) continue;
        lines[index] = '';
        if (removedSeen.add(text)) removed.add(original.trim());
      }
    }

    return PageFurnitureReport(
      pages: pageLines.map((lines) => lines.join('\n')).toList(growable: false),
      removedLines: List.unmodifiable(removed),
    );
  }

  /// The lines where furniture sits: the first non-empty lines of the page, and
  /// either the lines the PDF put in its bottom band or, without those
  /// coordinates, the last non-empty lines.
  List<_Edge> _edges(List<String> lines, {Set<int> footer = const <int>{}}) {
    final filled = <int>[];
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].trim().isNotEmpty) filled.add(index);
    }
    final edges = <_Edge>[];
    final seen = <int>{};
    for (var count = 0; count < edgeLines && count < filled.length; count++) {
      final fromTop = filled[count];
      if (seen.add(fromTop)) {
        edges.add(_Edge(index: fromTop, slot: 'top$count'));
      }
      if (footer.isNotEmpty) continue;
      final fromBottom = filled[filled.length - 1 - count];
      if (seen.add(fromBottom)) {
        edges.add(_Edge(index: fromBottom, slot: 'bottom$count'));
      }
    }
    for (final index in footer) {
      if (index < 0 || index >= lines.length || !seen.add(index)) continue;
      edges.add(_Edge(index: index, slot: 'footer'));
    }
    return edges;
  }

  /// A header printed with a changing number ("PMES2401 | 001-Prova") only
  /// matches its twin once the digits are ignored. Requiring real words keeps a
  /// line of digits — how boards write a question number — out of this rule.
  static String? _masked(String text) {
    if (text.length < 8 || text.length > 44) return null;
    if (_questionLabel.hasMatch(text)) return null;
    final letters = _letters.allMatches(text).length;
    final isCode = _codeToken.hasMatch(text);
    if (letters < 6 && !(letters >= 2 && isCode)) return null;
    return text.replaceAll(_digits, '#');
  }

  /// Rules that hold wherever the line sits: a watermark tiled across the sheet
  /// and a line that is nothing but the print date and time.
  static bool _isAlwaysDecoration(String text) {
    if (_questionLabel.hasMatch(text)) return false;
    if (_dateStamp.hasMatch(text) || _timeStamp.hasMatch(text)) return true;
    if (text.length < 12) return false;
    if (text.contains(' ')) {
      final repeat = _repeatedToken.firstMatch(text);
      return repeat != null && repeat.group(1)!.length >= 3;
    }
    return _isTiledWatermark(text);
  }

  /// `ENEM2025ENEM2025ENEN2025ENEM2025…` — one token stamped side by side until
  /// the page runs out of room, with the odd letter dropped by the text layer.
  /// A tiled line repeats itself almost exactly every `period` characters, and
  /// no sentence of that shape does.
  static bool _isTiledWatermark(String text) {
    if (text.length < 40) return false;
    for (var period = 3; period <= 24 && period * 4 <= text.length; period++) {
      var same = 0;
      var total = 0;
      for (var i = 0; i + period < text.length; i++) {
        total++;
        if (text.codeUnitAt(i) == text.codeUnitAt(i + period)) same++;
      }
      if (total > 0 && same / total >= .9) return true;
    }
    return false;
  }

  static bool _isCodeStamp(String text) =>
      !text.contains(' ') &&
      _codeToken.hasMatch(text) &&
      _digits.hasMatch(text) &&
      _letters.allMatches(text).length >= 2;

  /// A bare number only counts as a page number at the foot of the page: many
  /// boards open a page with the question number of the first column.
  static int? _pageNumberValue(String text, String slot) {
    final explicit =
        _pageNumberWord.hasMatch(text) || _numberedPair.hasMatch(text);
    if (!explicit && (slot.startsWith('top') || !_bareNumber.hasMatch(text))) {
      return null;
    }
    final first = _digits.firstMatch(text);
    if (first == null) return null;
    return int.tryParse(first.group(0)!);
  }

  static bool _isPageNumberInSlot(
    String text,
    String slot,
    int page,
    int? offset,
  ) {
    final value = _pageNumberValue(text, slot);
    return value != null && offset == value - page;
  }

  /// Page numbers advance exactly one per page, so `value - page` is the same
  /// on nearly every page. A question number that happens to close a column
  /// breaks that run, so only the numbers of the winning run are furniture.
  int? _pageOffset(List<_SlotNumber> samples, int pageCount) {
    if (pageCount < 2 || samples.length < 2) return null;
    final offsets = <int, int>{};
    for (final sample in samples) {
      final offset = sample.value - sample.page;
      offsets[offset] = (offsets[offset] ?? 0) + 1;
    }
    int? best;
    var bestCount = 0;
    offsets.forEach((offset, count) {
      if (count > bestCount) {
        best = offset;
        bestCount = count;
      }
    });
    // Enough pages must agree, and the run must dominate its slot: a slot that
    // only half-follows one count is a mix of question numbers, not a footer.
    if (bestCount < (pageCount * minimumShare).ceil()) return null;
    if (bestCount < (samples.length * .8).ceil()) return null;
    return best;
  }

  static String _signature(String line) =>
      line.trim().toUpperCase().replaceAll(_spaces, ' ');

  /// The page markers that `QuestionParser.parsePages` relies on are structure,
  /// not decoration: they must survive every furniture rule.
  static bool _isSentinel(String signature) =>
      signature.startsWith(ExamTextNormalizer.pageSentinel) ||
      signature.contains('PROVA_SOCIAL_PAGE_');
}

import 'question_parser.dart';

/// The answer key of an exam, as the board printed it.
///
/// Only the label of the correct alternative is kept (“A” to “H”, or “C”/“E”
/// for right-and-wrong items); the text of the alternative comes from the
/// question parsed from the same document.
class AnswerKey {
  const AnswerKey({
    required this.byNumber,
    required this.heading,
    required this.pages,
  });

  const AnswerKey.empty()
    : byNumber = const <int, String>{},
      heading = null,
      pages = const <int>[];

  /// Question number to the label of its correct alternative.
  final Map<int, String> byNumber;

  /// The title the key was read under, for the review screen.
  final String? heading;

  /// One-based pages that carried the key.
  final List<int> pages;

  bool get isEmpty => byNumber.isEmpty;

  int get length => byNumber.length;

  String? labelFor(int number) => byNumber[number];
}

/// What happened when a key was applied to the parsed questions.
class AnswerKeyApplication {
  const AnswerKeyApplication({
    required this.applied,
    required this.keyable,
    required this.unmatched,
    required this.withoutKey,
  });

  /// Questions that received their correct alternative from the key.
  final int applied;

  /// Questions that can carry a correct alternative at all.
  final int keyable;

  /// Key entries no question answered to — usually another booklet.
  final List<int> unmatched;

  /// Questions that stayed without a correct alternative.
  final List<int> withoutKey;

  bool get foundAnything => applied > 0;

  double get coverage => keyable == 0 ? 0 : applied / keyable;
}

/// Reads the “gabarito” a board prints at the end of the caderno or in a
/// separate file, and fills in the correct alternative of the questions.
///
/// A block is only believed when it behaves like a key: it opens under a title
/// (“GABARITO”, “CHAVE DE RESPOSTAS”, “RESULTADO PRELIMINAR”) or it is dense in
/// number-and-letter pairs, and its pairs cover a run of consecutive question
/// numbers. “01-B”, “(1) B”, “1 | A”, grids of “1 A  11 B  21 C” and the
/// right-and-wrong “1 – CERTO” all reduce to the same shape. A wrong key is
/// worse than no key, so anything that fails the test is left alone and the
/// manual review remains the only way to set the answer.
class AnswerKeyParser {
  const AnswerKeyParser({this.minimumRun = 3});

  /// A run of fewer consecutive question numbers is a mention, not a key.
  final int minimumRun;

  /// A key that carries no title at all has to prove itself with a long run.
  static const int _untitledMinimumRun = 10;
  static const int _maximumNumber = 400;

  static final RegExp _heading = RegExp(
    r'^\s*(?:gabarito|chave\s+de\s+(?:respostas?|gabarito)'
    r'|respostas?\s+(?:oficiais?|do\s+candidato)'
    r'|resultado\s+(?:preliminar|definitivo)|answer\s+key)\b',
    caseSensitive: false,
  );

  /// “1-B”, “01. B”, “(1) B”, “1) B”, “12 | A”, “01/A”, “1 A”. The V and F of
  /// the true-or-false boards ride along; they are not alternative labels.
  static final RegExp _letterPair = RegExp(
    r'(\d{1,3})\s*[).:\-–—/|\]]?\s*\(?([A-Ha-hVvFf])\)?(?![A-Za-zÀ-ÿ])',
    caseSensitive: false,
  );

  /// Right-and-wrong boards write the word out: “1 – CERTO”, “(2) ERRADO”.
  static final RegExp _wordPair = RegExp(
    r'(\d{1,3})\s*[).:\-–—/|\]]?\s*\(?\s*'
    r'(cert[oa]|errad[oa]|verdadeir[oa]|fals[oa])\b',
    caseSensitive: false,
  );

  static final RegExp _blank = RegExp(r'^\s*$');
  static final RegExp _standaloneNumber = RegExp(r'^\s*(\d{1,3})\s*$');
  static final RegExp _standaloneLabel = RegExp(
    r'^\s*\(?([A-Ha-hVvFf])\)?\s*$',
  );

  static final RegExp _pageMarker = RegExp(
    r'^\u0000PROVA_SOCIAL_PAGE_(\d+)\u0000$',
  );

  /// A whole key file — a second PDF or a page of notes without any title.
  AnswerKey parseText(String text) => parsePages([text]);

  AnswerKey parsePages(List<String> pages) {
    final titled = <_KeyBlock>[];
    for (var index = 0; index < pages.length; index++) {
      final lines = _visibleLines(pages[index]);
      for (var line = 0; line < lines.length; line++) {
        if (!_heading.hasMatch(lines[line])) continue;
        final block = _blockFrom(lines, line, pages, index);
        final entries = _entries(block.lines);
        if (!_trustworthy(entries)) continue;
        titled.add(
          _KeyBlock(
            entries: entries,
            pages: block.pages,
            heading: lines[line].trim(),
          ),
        );
      }
    }
    if (titled.isNotEmpty) return _merge(titled);
    return _denseRun(pages);
  }

  /// Two booklets of the same exam can both print a key, and their grids
  /// disagree. The block that answers the longest run of questions wins, and
  /// the others only fill the numbers it left open.
  AnswerKey _merge(List<_KeyBlock> blocks) {
    blocks.sort(_compareBlocks);
    final merged = <int, String>{};
    final keyPages = <int>{};
    for (final block in blocks) {
      keyPages.addAll(block.pages);
      block.entries.forEach((number, label) {
        merged.putIfAbsent(number, () => label);
      });
    }
    return AnswerKey(
      byNumber: Map.unmodifiable(merged),
      heading: blocks.first.heading,
      pages: keyPages.toList()..sort(),
    );
  }

  static int _compareBlocks(_KeyBlock a, _KeyBlock b) {
    final byRun = _strength(b.entries).compareTo(_strength(a.entries));
    if (byRun != 0) return byRun;
    final bySize = b.entries.length.compareTo(a.entries.length);
    if (bySize != 0) return bySize;
    return a.pages.first.compareTo(b.pages.first);
  }

  /// A key file without any title: the stretches of lines that pair a number
  /// with a letter. A grid that does not fit the column it started in is one
  /// key spread over several stretches, so the stretches that pass the test
  /// are read together, the strongest first.
  AnswerKey _denseRun(List<String> pages) {
    final runs = <_KeyBlock>[];
    var current = <String>[];
    var startPage = 0;
    var endPage = 0;
    void flush() {
      if (current.isEmpty) return;
      final entries = _entries(current);
      if (_strength(entries) >= _untitledMinimumRun) {
        runs.add(
          _KeyBlock(
            entries: entries,
            pages: [startPage, endPage],
            heading: null,
          ),
        );
      }
      current = <String>[];
    }

    for (var index = 0; index < pages.length; index++) {
      for (final line in _visibleLines(pages[index])) {
        if (_entries([line]).isNotEmpty) {
          if (current.isEmpty) startPage = index + 1;
          endPage = index + 1;
          current.add(line);
          continue;
        }
        if (_blank.hasMatch(line)) continue;
        flush();
      }
    }
    flush();
    if (runs.isEmpty) return const AnswerKey.empty();
    return _merge(runs);
  }

  /// The block a title opens: the rest of its page, and the following pages
  /// while they stay dense in pairs — a grid that does not fit one page is
  /// still one key. The next title closes it, so two booklets printed one
  /// after the other stay two separate keys.
  _KeyLines _blockFrom(
    List<String> lines,
    int start,
    List<String> pages,
    int pageIndex,
  ) {
    final block = <String>[];
    final covered = <int>[pageIndex + 1];
    for (var index = start; index < lines.length; index++) {
      if (index > start && _heading.hasMatch(lines[index])) {
        return (lines: block, pages: covered);
      }
      block.add(lines[index]);
    }
    var following = pageIndex + 1;
    while (following < pages.length) {
      final next = _visibleLines(pages[following]);
      if (!_isPairDense(next)) break;
      final taken = <String>[];
      for (final line in next) {
        if (_heading.hasMatch(line)) break;
        taken.add(line);
      }
      if (taken.isEmpty) break;
      block.addAll(taken);
      covered.add(following + 1);
      if (taken.length < next.length) break;
      following++;
    }
    return (lines: block, pages: covered);
  }

  bool _isPairDense(List<String> lines) {
    var content = 0;
    var paired = 0;
    for (final line in lines) {
      if (_blank.hasMatch(line)) continue;
      content++;
      if (_entries([line]).isNotEmpty) paired++;
    }
    return content > 0 && paired / content >= .6;
  }

  /// Question number to label, over the lines of one block.
  Map<int, String> _entries(List<String> block) {
    final pairs = <int, String>{};
    for (var index = 0; index < block.length; index++) {
      final line = block[index];
      for (final match in _wordPair.allMatches(line)) {
        final number = _number(match);
        if (number == null) continue;
        final word = match.group(2)!.toUpperCase();
        pairs.putIfAbsent(
          number,
          () => word.startsWith('C') || word.startsWith('V') ? 'C' : 'E',
        );
      }
      for (final match in _letterPair.allMatches(line)) {
        final number = _number(match);
        if (number == null) continue;
        pairs.putIfAbsent(number, () => match.group(2)!.toUpperCase());
      }
      final numberMatch = _standaloneNumber.firstMatch(line);
      if (numberMatch == null || index + 1 == block.length) continue;
      final labelMatch = _standaloneLabel.firstMatch(block[index + 1]);
      if (labelMatch == null) continue;
      final number = int.tryParse(numberMatch.group(1)!);
      if (number == null || number < 1 || number > _maximumNumber) continue;
      pairs.putIfAbsent(number, () => labelMatch.group(1)!.toUpperCase());
      index++;
    }
    return pairs;
  }

  int? _number(RegExpMatch match) {
    final value = int.tryParse(match.group(1) ?? '');
    if (value == null || value < 1 || value > _maximumNumber) return null;
    return value;
  }

  bool _trustworthy(Map<int, String> entries) =>
      _strength(entries) >= minimumRun;

  /// How much a block of lines behaves like a key.
  ///
  /// Boards print the grid column-major — 1 to 5 down one column, 11 to 15
  /// down the next — so a complete gabarito read line by line has a short
  /// stretch of consecutive numbers and long holes. When the answers still
  /// fill most of the range they span, all of them count; otherwise only an
  /// unbroken run counts, so a stray “artigo 5º, II, A” stays a mention.
  static int _strength(Map<int, String> entries) {
    final numbers = entries.keys.toSet();
    if (numbers.isEmpty) return 0;
    final sorted = numbers.toList()..sort();
    final range = sorted.last - sorted.first + 1;
    if (numbers.length >= _untitledMinimumRun && range <= numbers.length * 2) {
      return numbers.length;
    }
    return _longestConsecutiveRun(numbers);
  }

  /// Keys are printed in order, so a real one has a long stretch of
  /// consecutive numbers. A stray “artigo 5º, II, A” has only one.
  static int _longestConsecutiveRun(Iterable<int> numbers) {
    final sorted = numbers.toSet().toList()..sort();
    var best = 0;
    var run = 0;
    for (var index = 0; index < sorted.length; index++) {
      run = index > 0 && sorted[index] == sorted[index - 1] + 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  /// Fills the correct alternative of every question the key answers.
  ///
  /// A question a reviewer already answered is never overwritten.
  AnswerKeyApplication apply(AnswerKey key, List<ImportedQuestion> questions) {
    var applied = 0;
    var keyable = 0;
    final withoutKey = <int>[];
    final unmatched = <int>{...key.byNumber.keys};
    for (final question in questions) {
      final number = question.number;
      if (number == null || question.options.isEmpty) continue;
      keyable++;
      final label = key.byNumber[number];
      if (label == null) {
        withoutKey.add(number);
        continue;
      }
      unmatched.remove(number);
      // A question a reviewer already answered keeps the reviewer's choice.
      if (question.correctIndex != null) continue;
      final index = _optionIndex(question, label);
      if (index == null) {
        withoutKey.add(number);
        continue;
      }
      question.correctIndex = index;
      applied++;
    }
    return AnswerKeyApplication(
      applied: applied,
      keyable: keyable,
      unmatched: unmatched.toList()..sort(),
      withoutKey: withoutKey..sort(),
    );
  }

  /// A letter key counts from A; a right-and-wrong key points at CERTO or
  /// ERRADO, whichever order the question kept them in.
  int? _optionIndex(ImportedQuestion question, String label) {
    final options = question.options;
    if (options.isEmpty) return null;
    final judged =
        question.format == QuestionFormat.trueFalse ||
        (options.length == 2 && options.every(_isJudgementLabel));
    if (judged) {
      if (!_isJudgementLabel(label)) return null;
      final firstIsCerto = _isCertoWord(options.first);
      final labelIsCerto =
          label == 'C' ||
          label == 'V' ||
          label.startsWith('CERTO') ||
          label.startsWith('VERDADEIRO') ||
          label.startsWith('TRUE');
      return (labelIsCerto == firstIsCerto) ? 0 : 1;
    }
    final index = label.toUpperCase().runes.first - 'A'.runes.first;
    if (index < 0 || index >= options.length) return null;
    return index;
  }

  static bool _isJudgementLabel(String label) {
    final upper = label.toUpperCase();
    return upper == 'C' ||
        upper == 'E' ||
        upper == 'V' ||
        upper == 'F' ||
        _isCertoWord(upper) ||
        upper.startsWith('ERRAD') ||
        upper.startsWith('FALS');
  }

  static bool _isCertoWord(String option) {
    final upper = option.trim().toUpperCase();
    return upper == 'C' ||
        upper == 'CERTO' ||
        upper == 'V' ||
        upper.startsWith('CERTO') ||
        upper.startsWith('VERDADEIRO') ||
        upper.startsWith('TRUE');
  }

  static List<String> _visibleLines(String page) => page
      .split('\n')
      .where((line) => !_pageMarker.hasMatch(line))
      .toList(growable: false);
}

class _KeyBlock {
  const _KeyBlock({
    required this.entries,
    required this.pages,
    required this.heading,
  });

  final Map<int, String> entries;
  final List<int> pages;
  final String? heading;
}

/// The lines of one block and the pages they were read on.
typedef _KeyLines = ({List<String> lines, List<int> pages});

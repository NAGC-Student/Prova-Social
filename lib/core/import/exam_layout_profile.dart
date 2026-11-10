import 'exam_metadata_suggester.dart';

/// Recognises which board printed a caderno and how it marks its questions.
///
/// The name is read from the document itself, never guessed from the file
/// name, because candidates send the same PDF under different names. The
/// layout, on the other hand, is structural: a caderno full of answer boxes is
/// judged item by item, and one full of letters offers alternatives.
enum QuestionLayout { letteredAlternatives, judgementItems, mixed, unknown }

class ExamLayoutProfile {
  const ExamLayoutProfile({
    required this.banca,
    required this.layout,
    required this.evidencePages,
  });

  /// Board named in the document, or null when nothing says.
  final String? banca;

  final QuestionLayout layout;

  /// Pages the profile was read from, so the reviewer can confirm it.
  final List<int> evidencePages;

  bool get isKnown => banca != null || layout != QuestionLayout.unknown;

  /// Shown to the user: the board plus what the importer understood.
  String get label {
    final board = banca;
    return switch (layout) {
      QuestionLayout.judgementItems when board != null =>
        '$board — itens para julgar',
      QuestionLayout.judgementItems => 'Itens para julgar',
      QuestionLayout.letteredAlternatives when board != null =>
        '$board — alternativas de A a E',
      QuestionLayout.letteredAlternatives => 'Alternativas de A a E',
      QuestionLayout.mixed when board != null => '$board — formato misto',
      QuestionLayout.mixed => 'Formato misto',
      QuestionLayout.unknown when board != null => board,
      QuestionLayout.unknown => 'Formato não reconhecido',
    };
  }
}

class ExamLayoutProfiler {
  const ExamLayoutProfiler();

  static final RegExp _blankBox = RegExp(
    r'\(\s*\)|\(\s*[cCeE]\s*\)\s*\(\s*[eE]\s*\)',
  );

  /// One hit per lettered question: only the “A” label is counted, whether the
  /// board writes “(A) texto” or “A) texto”. The text is lowercased before the
  /// scan, so the class holds the lower letter alone.
  static final RegExp _firstOptionLabel = RegExp(
    r'(?:^|\s)\(a\)\s|(?:^|\s)a[.)\-–:]\s',
  );

  ExamLayoutProfile profile(List<String> pages, {String? sourceName}) {
    final joined = _flatten(pages);
    final metadata = suggestExamMetadata(
      fileName: sourceName ?? '',
      firstPageText: pages.firstOrNull ?? '',
      pages: pages.take(5).toList(growable: false),
    );
    final banca = metadata.board;
    final bancaPage = metadata.evidencePages['board'] ?? 0;

    final boxes = _blankBox.allMatches(joined).length;
    final letters = _firstOptionLabel.allMatches(joined).length;
    final layout = switch ((boxes, letters)) {
      (>= 3, >= 1) => QuestionLayout.mixed,
      (>= 3, 0) => QuestionLayout.judgementItems,
      (< 3, >= 1) => QuestionLayout.letteredAlternatives,
      _ => QuestionLayout.unknown,
    };
    return ExamLayoutProfile(
      banca: banca,
      layout: layout,
      evidencePages: [if (banca != null) bancaPage],
    );
  }

  static String _flatten(List<String> pages) => pages.join('\n').toLowerCase();
}

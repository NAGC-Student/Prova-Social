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

  /// Boards that sign the first pages of their cadernos. Written as they are
  /// printed, so a match is a quote from the document and not a guess.
  static const _boards = <String, List<String>>{
    'CEBRASPE': ['cebraspe', 'cespe', 'instituto american'],
    'VUNESP': ['vunesp', 'fundação para o vestibular'],
    'FGV': [
      'fundação getulio vargas',
      'fundação getúlio vargas',
      'fgv projetos',
    ],
    'FCC': ['carlos chagas', 'fcc — fundação', 'fundação carlos'],
    'IBFC': ['ibfc', 'instituto brasileiro de formação e carreira'],
    'FUNDATEC': ['fundatec'],
    'Quadrix': ['quadrix'],
    'Instituto AOCP': ['aocp'],
    'Consulplan': ['consulplan', 'instituto consulplan'],
    'NUPECE': ['nucleo de tecnologia e competencias', 'nupece'],
    'COMPERVE': ['comperve'],
    'IBADE': ['ibade'],
    'FUVEST': ['fuvest'],
    'UERJ': ['uerj'],
    'UFPR': ['ufpr', 'nuvem'],
    'Instituto Mais': ['instituto mais'],
    'ISEA': ['instituto superior de educacao', 'isea'],
    'ENEM': ['exame nacional do ensino medio', 'enem'],
  };

  static final RegExp _blankBox = RegExp(
    r'\(\s*\)|\(\s*[cCeE]\s*\)\s*\(\s*[eE]\s*\)',
  );

  /// One hit per lettered question: only the “A” label is counted, whether the
  /// board writes “(A) texto” or “A) texto”. The text is lowercased before the
  /// scan, so the class holds the lower letter alone.
  static final RegExp _firstOptionLabel = RegExp(
    r'(?:^|\s)\(a\)\s|(?:^|\s)a[.)\-–:]\s',
  );

  ExamLayoutProfile profile(List<String> pages) {
    final joined = _flatten(pages);
    String? banca;
    var bancaPage = 0;
    // A board is named on the cover, so the signature printed first wins. A
    // text passage in question 38 that mentions Getúlio Vargas must not
    // outvote the institute that signed page one.
    for (final entry in _boards.entries) {
      for (final signal in entry.value) {
        final found = _pageIndexOf(pages, signal);
        if (found != null && (banca == null || found < bancaPage)) {
          banca = entry.key;
          bancaPage = found;
        }
      }
    }

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

  /// First page (1-based) whose text carries the signal.
  static int? _pageIndexOf(List<String> pages, String signal) {
    for (var index = 0; index < pages.length; index++) {
      if (pages[index].toLowerCase().contains(signal)) return index + 1;
    }
    return null;
  }
}

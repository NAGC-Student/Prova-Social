class ExamMetadataSuggestion {
  const ExamMetadataSuggestion({
    this.title,
    this.year,
    this.category,
    this.board,
    this.institution,
    this.instance,
    this.evidencePages = const {},
    this.evidenceSources = const {},
  });

  final String? title;
  final int? year;
  final String? category;
  final String? board;
  final String? institution;
  final String? instance;
  final Map<String, int> evidencePages;
  final Map<String, String> evidenceSources;

  List<String> get fieldsNeedingAttention => [
    for (final field in const [
      'title',
      'board',
      'institution',
      'category',
      'year',
      'instance',
    ])
      if (!evidencePages.containsKey(field)) field,
  ];

  Map<String, Object?> toJson() => {
    'values': {
      'title': title,
      'year': year,
      'category': category,
      'board': board,
      'institution': institution,
      'instance': instance,
    },
    'evidence': {
      for (final field in evidenceSources.keys)
        field: {
          'source': evidenceSources[field],
          'page': ?evidencePages[field],
        },
    },
    'fieldsNeedingAttention': fieldsNeedingAttention,
  };
}

class _MetadataSignature {
  const _MetadataSignature(this.value, this.pattern);

  final String value;
  final RegExp pattern;
}

class _MetadataMatch {
  const _MetadataMatch(this.value, this.page);

  final String value;
  final int page;
}

final _boardSignatures = <_MetadataSignature>[
  _MetadataSignature('CEBRASPE', RegExp(r'\b(?:cebraspe|cespe)\b')),
  _MetadataSignature('VUNESP', RegExp(r'\bvunesp\b')),
  _MetadataSignature(
    'FGV',
    RegExp(r'\b(?:fgv(?: projetos| conhecimento)?|fundacao getulio vargas)\b'),
  ),
  _MetadataSignature('FCC', RegExp(r'\b(?:fcc|fundacao carlos chagas)\b')),
  _MetadataSignature('FUVEST', RegExp(r'\bfuvest\b')),
  _MetadataSignature(
    'COMVEST',
    RegExp(r'\bcomvest\b|comissao permanente (?:para|dos) vestibulares'),
  ),
  _MetadataSignature('IBFC', RegExp(r'\bibfc\b')),
  _MetadataSignature('FUNDATEC', RegExp(r'\bfundatec\b')),
  _MetadataSignature('Quadrix', RegExp(r'\bquadrix\b')),
  _MetadataSignature('Instituto AOCP', RegExp(r'\b(?:aocp|instituto aocp)\b')),
  _MetadataSignature('Consulplan', RegExp(r'\bconsulplan\b')),
  _MetadataSignature('NUPECE', RegExp(r'\bnupece\b')),
  _MetadataSignature('COMPERVE', RegExp(r'\bcomperve\b')),
  _MetadataSignature('IBADE', RegExp(r'\bibade\b')),
];

final _institutionSignatures = <_MetadataSignature>[
  _MetadataSignature(
    'Instituto Tecnológico de Aeronáutica (ITA)',
    RegExp(r'\binstituto tecnologico de aeronautica\b'),
  ),
  _MetadataSignature(
    'Academia da Força Aérea (AFA)',
    RegExp(r'\bacademia da forca aerea\b'),
  ),
  _MetadataSignature(
    'Escola Preparatória de Cadetes do Exército (EsPCEx)',
    RegExp(r'\bescola preparatoria de cadetes do exercito\b|\bespcex\b'),
  ),
  _MetadataSignature('Escola Naval', RegExp(r'\bescola naval\b')),
  _MetadataSignature(
    'Escola de Formação de Oficiais da Marinha Mercante (EFOMM)',
    RegExp(r'\bescola de formacao de oficiais da marinha mercante\b|\befomm\b'),
  ),
  _MetadataSignature(
    'Escola de Sargentos das Armas (ESA)',
    RegExp(r'\bescola de sargentos das armas\b'),
  ),
  _MetadataSignature(
    'Instituto Nacional de Estudos e Pesquisas Educacionais (INEP)',
    RegExp(
      r'\binstituto nacional de estudos e pesquisas educacionais\b|\binep\b',
    ),
  ),
  _MetadataSignature(
    'Agência Nacional de Mineração (ANM)',
    RegExp(r'\bcebraspe\s+anm\b'),
  ),
  _MetadataSignature(
    'Agência Espacial Brasileira (AEB)',
    RegExp(r'agencia espacial brasileira'),
  ),
  _MetadataSignature(
    'Universidade de São Paulo (USP)',
    RegExp(r'universidade de sao paulo'),
  ),
  _MetadataSignature(
    'Universidade Estadual de Campinas (UNICAMP)',
    RegExp(r'universidade estadual de campinas'),
  ),
  _MetadataSignature(
    'Assembleia Legislativa do Estado do Maranhão (ALEMA)',
    RegExp(r'assembleia legislativ[oa] do (?:estado do )?maranhao'),
  ),
];

/// Returns only metadata supported by text on the first five document pages.
/// A filename may suggest a title, but never a board, institution, or year.
ExamMetadataSuggestion suggestExamMetadata({
  required String fileName,
  required String firstPageText,
  List<String>? pages,
}) {
  final inspectedPages = (pages ?? [firstPageText])
      .take(5)
      .toList(growable: false);
  final normalizedPages = inspectedPages.map(_normalize).toList();
  final evidencePages = <String, int>{};
  final evidenceSources = <String, String>{};

  final boardMatch = _findSignature(
    normalizedPages,
    _boardSignatures,
    inspectedPages,
  );
  final institutionMatch = _findInstitution(normalizedPages, inspectedPages);
  final categoryMatch = _findCategory(inspectedPages);
  final yearMatch = _findYear(normalizedPages);
  final year = int.tryParse(yearMatch?.value ?? '');
  final instanceMatch = _findInstance(inspectedPages);

  for (final entry in {
    'board': boardMatch,
    'institution': institutionMatch,
    'category': categoryMatch,
    'year': yearMatch,
    'instance': instanceMatch,
  }.entries) {
    if (entry.value != null) {
      evidencePages[entry.key] = entry.value!.page;
      evidenceSources[entry.key] = 'document';
    }
  }

  final documentTitle = _findTitle(
    inspectedPages,
    normalizedPages,
    board: boardMatch?.value,
    institution: institutionMatch?.value,
    year: year,
    category: categoryMatch?.value,
    instance: instanceMatch?.value,
  );
  final fileTitle = _cleanTitle(
    fileName
        .split(RegExp(r'[/\\]'))
        .last
        .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
  );
  final title =
      documentTitle ??
      (fileTitle.length >= 5 && !_looksGenericTitle(fileTitle)
          ? fileTitle
          : null);
  if (documentTitle != null) {
    evidencePages['title'] = _titleEvidencePage(
      inspectedPages,
      normalizedPages,
      documentTitle,
    );
    evidenceSources['title'] = 'document';
  } else if (title != null) {
    evidenceSources['title'] = 'filename';
  }

  return ExamMetadataSuggestion(
    title: title,
    year: year,
    category: categoryMatch?.value,
    board: boardMatch?.value,
    institution: institutionMatch?.value,
    instance: instanceMatch?.value,
    evidencePages: Map.unmodifiable(evidencePages),
    evidenceSources: Map.unmodifiable(evidenceSources),
  );
}

_MetadataMatch? _findSignature(
  List<String> pages,
  List<_MetadataSignature> signatures,
  List<String> sourcePages,
) {
  for (var index = 0; index < pages.length; index++) {
    final matches = signatures
        .where(
          (signature) => _hasSignatureEvidence(
            signature,
            sourcePages[index],
            pages[index],
          ),
        )
        .map((signature) => signature.value)
        .toSet();
    if (matches.isEmpty) continue;
    if (matches.length != 1) return null;
    return _MetadataMatch(matches.single, index + 1);
  }
  return null;
}

_MetadataMatch? _findInstitution(
  List<String> normalizedPages,
  List<String> sourcePages,
) {
  final match = _findSignature(
    normalizedPages,
    _institutionSignatures,
    sourcePages,
  );
  if (match != null) return match;

  for (var index = 0; index < sourcePages.length; index++) {
    final lines = sourcePages[index].split(RegExp(r'\r?\n'));
    for (
      var lineIndex = 0;
      lineIndex < lines.length && lineIndex < 32;
      lineIndex++
    ) {
      final line = lines[lineIndex].trim();
      final direct = RegExp(
        r'^PREFEITURA MUNICIPAL\s+(?:DE|DO|DA)\s+'
        r'([A-ZÀ-Ú][A-ZÀ-Úa-zà-ÿ]*(?:\s+[A-ZÀ-Ú][A-ZÀ-Úa-zà-ÿ]*)?)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (direct != null) {
        return _MetadataMatch(
          'Prefeitura Municipal de ${_titleCase(direct.group(1)!)}',
          index + 1,
        );
      }

      if (_normalize(line) != 'prefeitura municipal' ||
          lineIndex + 1 >= lines.length) {
        continue;
      }
      final next = RegExp(
        r'^\s*(?:DE|DO|DA)\s+'
        r'([A-ZÀ-Ú][A-ZÀ-Úa-zà-ÿ]*(?:\s+[A-ZÀ-Ú][A-ZÀ-Úa-zà-ÿ]*)?)\s*$',
        caseSensitive: false,
      ).firstMatch(lines[lineIndex + 1]);
      if (next != null) {
        return _MetadataMatch(
          'Prefeitura Municipal de ${_titleCase(next.group(1)!)}',
          index + 1,
        );
      }
    }

    for (
      var lineIndex = 0;
      lineIndex < lines.length && lineIndex < 32;
      lineIndex++
    ) {
      if (_normalize(lines[lineIndex]) != 'assembleia legislativo do' &&
          _normalize(lines[lineIndex]) != 'assembleia legislativa do') {
        continue;
      }
      if (lineIndex + 1 < lines.length &&
          RegExp(r'^\s*ESTADO\s+DO\s+MARANH[AÃ]O\s*$')
              .hasMatch(lines[lineIndex + 1])) {
        return _MetadataMatch(
          'Assembleia Legislativa do Estado do Maranhão (ALEMA)',
          index + 1,
        );
      }
    }

    for (final line in lines.take(32)) {
      if (RegExp(
        r'^\s*UNICAMP\s+VESTIBULAR\s+20\d{2}\b',
        caseSensitive: false,
      ).hasMatch(line)) {
        return _MetadataMatch(
          'Universidade Estadual de Campinas (UNICAMP)',
          index + 1,
        );
      }
    }
  }
  return null;
}

bool _hasSignatureEvidence(
  _MetadataSignature signature,
  String sourcePage,
  String normalizedPage,
) {
  if (!signature.pattern.hasMatch(normalizedPage)) return false;
  for (final line in sourcePage.split(RegExp(r'\r?\n'))) {
    if (RegExp(r'\b(?:https?://|www\.)', caseSensitive: false).hasMatch(line)) {
      continue;
    }
    final normalizedLine = _normalize(line);
    if (!signature.pattern.hasMatch(normalizedLine)) continue;
    if (RegExp(
      r'\b(?:adaptad[oa]|basead[oa]|elaboracao|fonte|referencia|'
      r'disponivel em|acesso em)\b',
    ).hasMatch(normalizedLine)) {
      continue;
    }
    if (signature.value.startsWith('Universidade de') &&
        !normalizedLine.startsWith(
          signature.value == 'Universidade de São Paulo (USP)'
              ? 'universidade de sao paulo'
              : 'universidade estadual de campinas',
        )) {
      continue;
    }
    if (signature.value.startsWith('Assembleia Legislativa') &&
        !normalizedLine.startsWith('assembleia legislativa do maranhao')) {
      continue;
    }
    if (signature.value == 'FGV' &&
        normalizedLine.trim() != 'fgv' &&
        !RegExp(r'\bfgv\s+(?:projetos|conhecimento)\b')
            .hasMatch(normalizedLine) &&
        !RegExp(r'\bfundacao getulio vargas\b').hasMatch(normalizedLine)) {
      continue;
    }
    return true;
  }
  return false;
}

_MetadataMatch? _findCategory(List<String> sourcePages) {
  const categories = <(String, String)>[
    (
      'Exame nacional',
      r'^(?:exame nacional do ensino medio|enem\s*20\d{2}|enem20\d{2})',
    ),
    ('Concurso de admissão', r'^concurso de admissao\b'),
    ('Concurso público', r'^(?:concurso publico|concurso para provimento)\b'),
    (
      'Vestibular',
      r'^(?:concurso vestibular|vestibular(?:\s|$)|'
          r'(?:unicamp|fuvest)\s+vestibular(?:\s|$))',
    ),
    ('Processo seletivo', r'^processo seletivo\b'),
  ];

  for (var index = 0; index < sourcePages.length; index++) {
    for (final line in sourcePages[index].split(RegExp(r'\r?\n'))) {
      final normalizedLine = _normalize(line);
      for (final (category, pattern) in categories) {
        if (RegExp(pattern).hasMatch(normalizedLine)) {
          return _MetadataMatch(category, index + 1);
        }
      }
    }
  }
  return null;
}

_MetadataMatch? _findYear(List<String> pages) {
  final yearPattern = RegExp(r'\b(19\d{2}|20\d{2}|21\d{2})\b|enem(20\d{2})');
  final examContext = RegExp(
    r'\b(?:vestibular|concurso|prova|exame|fuvest|unicamp|ita|espcex|afa|'
    r'efomm|anm|aeb)\b|'
    r'\benem\b|enem20\d{2}',
  );
  final publicationContext = RegExp(
    r'\b(?:edital|publicad[oa]|atualizad[oa]|versao|copyright|arquivo)\b',
  );

  for (var index = 0; index < pages.length; index++) {
    for (final line in pages[index].split('\n')) {
      final enemYear = RegExp(r'\benem\s*(20\d{2})\b|enem(20\d{2})')
          .firstMatch(line);
      if (enemYear != null) {
        return _MetadataMatch(
          enemYear.group(1) ?? enemYear.group(2)!,
          index + 1,
        );
      }
      if (publicationContext.hasMatch(line) || !examContext.hasMatch(line)) {
        continue;
      }
      final match = yearPattern.firstMatch(line);
      if (match == null) continue;
      final yearText = match.group(1) ?? match.group(2);
      final year = int.tryParse(yearText ?? '');
      if (year != null && year >= 1900 && year <= 2200) {
        return _MetadataMatch(year.toString(), index + 1);
      }
    }
  }
  return null;
}

_MetadataMatch? _findInstance(List<String> pages) {
  for (var index = 0; index < pages.length; index++) {
    final normalizedLines = pages[index]
        .split(RegExp(r'\r?\n'))
        .map(_normalize)
        .toList(growable: false);
    final page = normalizedLines.join(' ');
    final parts = <String>[];
    final phase = RegExp(
      r'\b(1|2|3|primeira|segunda|terceira)[ \t]*[ao]?[ \t]*fase\b',
    ).firstMatch(page);
    if (phase != null) {
      parts.add('${_ordinal(phase.group(1)!)} fase');
    }
    final dayPattern = RegExp(
      r'\b(1|2|3|primeiro|segundo|terceiro)[ \t]*[ao]?[ \t]*dia\b',
    );
    final headerDayMatches = <RegExpMatch>[];
    final standaloneDayMatches = <RegExpMatch>[];
    for (final line in normalizedLines.take(24)) {
      final matches = dayPattern.allMatches(line).toList(growable: false);
      if (matches.isEmpty) continue;
      final standaloneDay = RegExp(
        r'^(?:1|2|3|primeiro|segundo|terceiro)[ \t]*[ao]?[ \t]*dia$',
      ).hasMatch(line);
      if (line.contains('caderno') || line.contains('|')) {
        headerDayMatches.addAll(matches);
      } else if (standaloneDay) {
        standaloneDayMatches.addAll(matches);
      }
    }
    final dayMatches = headerDayMatches.isNotEmpty
        ? headerDayMatches
        : standaloneDayMatches;
    final dayNumbers = dayMatches.map((match) => match.group(1)).toSet();
    if (dayNumbers.length > 1) return null;
    if (dayMatches.isNotEmpty) {
      parts.add('${_ordinal(dayMatches.first.group(1)!, feminine: false)} dia');
    }
    final booklet = RegExp(
      r'\bcaderno[ \t]+(?:n[oa]?[ \t]*)?([0-9]+|azul|amarelo|branco|rosa|verde|laranja|cinza)\b'
      r'(?:[ \t]+(azul|amarelo|branco|rosa|verde|laranja|cinza))?',
    ).firstMatch(page);
    if (booklet != null) {
      parts.add(
        'Caderno ${booklet.group(1)!.toUpperCase()}'
        '${booklet.group(2) == null ? '' : ' — ${_capitalize(booklet.group(2)!)}'}',
      );
    }
    final type = RegExp(
      r'\btipo(?:[ \t]+de[ \t]+prova)?[ \t]*:?[ \t]+([0-9]+|[a-z])'
      r'(?:[ \t]+(azul|amarelo|branco|rosa|verde|'
      r'laranja|cinza))?\b',
    ).firstMatch(page);
    if (type != null) {
      parts.add(
        'Tipo ${type.group(1)!.toUpperCase()}'
        '${type.group(2) == null ? '' : ' — ${_capitalize(type.group(2)!)}'}',
      );
    }
    final section = RegExp(r'\bparte[ \t]+(i{1,3}|[123])\b').firstMatch(page);
    if (section != null) {
      parts.add('Parte ${section.group(1)!.toUpperCase()}');
    }
    if (parts.isNotEmpty) {
      return _MetadataMatch(parts.toSet().join(' · '), index + 1);
    }
  }
  return null;
}

String? _findTitle(
  List<String> pages,
  List<String> normalizedPages, {
  required String? board,
  required String? institution,
  required int? year,
  required String? category,
  required String? instance,
}) {
  final allText = normalizedPages.join('\n');
  final isEnem = RegExp(r'\benem(?:\s*20\d{2})?\b|enem20\d{2}')
      .hasMatch(allText);
  if (isEnem && year != null) {
    return _joinTitle('ENEM $year', instance);
  }
  if (board == 'FUVEST' && year != null) {
    return _joinTitle('FUVEST $year', instance);
  }
  if (board == 'COMVEST' && year != null) {
    return _joinTitle('Vestibular Unicamp $year', instance);
  }
  final unicampTitle = RegExp(r'\bunicamp\s+vestibular\s+(20\d{2})\b')
      .firstMatch(allText);
  if (unicampTitle != null) {
    return _joinTitle('Vestibular Unicamp ${unicampTitle.group(1)}', instance);
  }
  if (board == 'CEBRASPE' &&
      RegExp(r'\bcebraspe\s+anm\b').hasMatch(allText) &&
      RegExp(r'\bprovas? objetivas?\b').hasMatch(allText)) {
    return _joinTitle('ANM — Provas objetivas', instance);
  }
  if (board == 'CEBRASPE' &&
      RegExp(r'\bcebraspe\s+aeb\b').hasMatch(allText) &&
      RegExp(r'\bprovas? objetivas?\b').hasMatch(allText)) {
    return _joinTitle('AEB — Provas objetivas', instance);
  }
  if (institution?.contains('(ITA)') == true &&
      RegExp(r'\bvestibular\b').hasMatch(allText)) {
    return _joinTitle(
      'Vestibular ITA${year == null ? '' : ' $year'}',
      instance,
    );
  }
  if (institution?.contains('(AFA)') == true) {
    return _joinTitle('Seleção AFA${year == null ? '' : ' $year'}', instance);
  }
  if (board == 'FGV' &&
      RegExp(r'\bjuiz substituto\b').hasMatch(allText) &&
      RegExp(r'\bprova escrita discursiva\b').hasMatch(allText)) {
    return _joinTitle('Juiz Substituto — Prova escrita discursiva', instance);
  }
  if (institution?.contains('(ANM)') == true &&
      RegExp(r'\bprova discursiva\b').hasMatch(allText)) {
    return _joinTitle('ANM — Prova discursiva', instance);
  }
  if (category == 'Concurso de admissão' && year != null) {
    return _joinTitle('Concurso de Admissão $year', instance);
  }

  for (var index = 0; index < pages.length; index++) {
    for (final line in pages[index].split(RegExp(r'\r?\n'))) {
      final cleaned = _cleanTitle(line);
      if (RegExp(r'[\u2022\u2023\u25e6\u2043\u25aa\u25cf\uF0B7]')
          .hasMatch(cleaned)) {
        continue;
      }
      final normalized = _normalize(cleaned);
      if (institution != null &&
          normalized ==
              _normalize(
                institution.replaceFirst(RegExp(r'\s*\([^)]*\)$'), ''),
              )) {
        continue;
      }
      if (!_isInformativeTitle(normalized)) continue;
      if (board == 'FGV' &&
          RegExp(r'\bjuiz substituto\b').hasMatch(normalized)) {
        return _joinTitle('Juiz Substituto — Prova discursiva', instance);
      }
      if (board != null && !normalized.contains(_normalize(board))) {
        return _joinTitle('$board — $cleaned', instance);
      }
      return _joinTitle(cleaned, instance);
    }
  }

  if (category != null && institution != null) {
    return _joinTitle('$institution — $category', instance);
  }
  return null;
}

int _titleEvidencePage(
  List<String> pages,
  List<String> normalizedPages,
  String title,
) {
  final firstPart = _normalize(title.split(' — ').last);
  for (var index = 0; index < normalizedPages.length; index++) {
    if (normalizedPages[index].contains(firstPart)) return index + 1;
    if (pages[index]
        .split(RegExp(r'\r?\n'))
        .any((line) => _normalize(line).contains(firstPart))) {
      return index + 1;
    }
  }
  return 1;
}

String _joinTitle(String title, String? instance) {
  if (instance == null || _normalize(title).contains(_normalize(instance))) {
    return title;
  }
  return '$title — $instance';
}

bool _isInformativeTitle(String value) {
  if (value.length < 7 ||
      value.length > 120 ||
      (value.split(RegExp(r'\s+')).length > 6 &&
          RegExp(r'[.!?;:]$').hasMatch(value)) ||
      RegExp(r'^(?:\d+|pagina \d+|questao \d+|caderno \d+)$').hasMatch(value) ||
      RegExp(
        r'^(?:concurso publico|prova|prova objetiva(?: parte (?:i|ii|iii|[123]))?|'
        r'prova discursiva|prova escrita discursiva|instrucoes|'
        r'informacoes gerais|exame nacional do ensino medio|vestibular|edital)'
        r'(?:\s+parte (?:i|ii|iii|[123]))?$',
      ).hasMatch(value)) {
    return false;
  }
  if (RegExp(
    r'^(?:fgv(?: projetos| conhecimento)?|cebraspe|cespe|vunesp|fcc|'
    r'fuvest|comvest|ibfc|fundatec|quadrix|instituto aocp|consulplan)$',
  ).hasMatch(value)) {
    return false;
  }
  if (RegExp(
    r'^caderno\s+(?:[0-9]+|azul|amarelo|branco|rosa|verde|laranja|cinza)'
    r'(?:\s+(?:azul|amarelo|branco|rosa|verde|laranja|cinza))?$',
  ).hasMatch(value)) {
    return false;
  }
  if (RegExp(
    r'\b(?:candidato|recebeu sua folha|abra este caderno|edital|'
    r'confira seus dados|leia atentamente|edital:|questao \d+|'
    r'respostas?|alternativas?|proibicoes|orientacoes continuam validas|'
    r'aguarde a ordem do fiscal|abrir este caderno|retirar se da sala|'
    r'levar o caderno de questoes|horas apos o inicio da prova|'
    r'nas questoes a seguir|nas questoes de lingua|marque para cada item|'
    r'cada um dos itens das provas objetivas|sua prova|tempo|'
    r'nao sera permitido|folha de respostas|eventuais espacos livres|'
    r'questoes objetivas|questoes discursivas|caderno contendo|'
    r'nivel superior|tipo de prova|assembleia legislativ[oa]|estado do maranhao|'
    r'inscricao escola sala lugar na sala)\b',
  ).hasMatch(value)) {
    return false;
  }
  if (RegExp(
    r'^(?:prefeitura municipal(?: de| do| da)?|'
    r'assembleia legislativa(?: do| de| da)?|'
    r'ministerio (?:da|do|de) [a-z ]+|exercito brasileiro|'
    r'marinha do brasil|forca aerea brasileira)$',
  ).hasMatch(value)) {
    return false;
  }
  return RegExp(r'[a-z]{3,}').allMatches(value).length >= 2;
}

bool _looksGenericTitle(String value) =>
    !_isInformativeTitle(_normalize(value.replaceAll(RegExp(r'[_-]+'), ' ')));

String _ordinal(String value, {bool feminine = true}) {
  final number = switch (value) {
    'primeira' || 'primeiro' => '1',
    'segunda' || 'segundo' => '2',
    'terceira' || 'terceiro' => '3',
    _ => value,
  };
  final suffix = feminine ? 'ª' : 'º';
  return '$number$suffix';
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _titleCase(String value) =>
    value.toLowerCase().split(RegExp(r'\s+')).map(_capitalize).join(' ');

String _cleanTitle(String value) => value
    .replaceAll(RegExp(r'^\s*\d+[.)-]\s*'), '')
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(
      RegExp(r'\b(c[oó]pia|copy|scan|digitalizado)\b', caseSensitive: false),
      '',
    )
    .trim();

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('ª', 'a')
    .replaceAll('º', 'o')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'text_normalizer.dart';

/// Universal-ish exam/question parser.
///
/// Structural uncertainty is kept on the resulting question for human review;
/// detected candidates are not silently discarded because their format differs.
class ImportedQuestion {
  ImportedQuestion({
    required this.statement,
    required this.options,
    this.correctIndex,
    this.number,
    String? id,
    this.sourcePage,
    List<int>? sourcePages,
    this.sourcePosition,
    this.instructions,
    this.subject,
    this.topic,
    this.language,
    List<String>? supportingMaterialIds,
    Map<String, double>? fieldConfidence,
    List<String>? warnings,
    this.format = QuestionFormat.multipleChoice,
    this.confidence = 0,
    this.warning,
    QuestionReviewState? reviewState,
    this.versionLabel = 'Versão principal',
    List<ImportedQuestionVersion>? alternateVersions,
  }) : id = id ?? _stableQuestionId(number, sourcePage, statement),
       sourcePages =
           sourcePages ?? (sourcePage == null ? <int>[] : <int>[sourcePage]),
       supportingMaterialIds = supportingMaterialIds ?? <String>[],
       fieldConfidence = fieldConfidence ?? <String, double>{},
       warnings =
           warnings ?? (warning == null ? <String>[] : <String>[warning]),
       reviewState =
           reviewState ??
           (warning != null || confidence < lowConfidenceQuestionThreshold
               ? QuestionReviewState.needsAttention
               : confidence >= autoValidatedQuestionConfidence
               ? QuestionReviewState.reviewed
               : QuestionReviewState.unreviewed),
       alternateVersions = alternateVersions ?? <ImportedQuestionVersion>[];

  String statement;
  List<String> options;
  int? correctIndex;
  int? number;
  String id;
  int? sourcePage;
  final List<int> sourcePages;
  int? sourcePosition;
  String? instructions;
  String? subject;
  String? topic;
  String? language;
  final List<String> supportingMaterialIds;
  final Map<String, double> fieldConfidence;
  final List<String> warnings;
  QuestionFormat format;
  double confidence;
  String? warning;
  QuestionReviewState reviewState;
  String versionLabel;
  final List<ImportedQuestionVersion> alternateVersions;

  void selectAlternateVersion(int index) {
    if (index < 0 || index >= alternateVersions.length) return;
    final previous = ImportedQuestionVersion(
      label: versionLabel,
      statement: statement,
      options: List.of(options),
      correctIndex: correctIndex,
      format: format,
      confidence: confidence,
      warning: warning,
    );
    final selected = alternateVersions[index];
    statement = selected.statement;
    options = List.of(selected.options);
    correctIndex = selected.correctIndex;
    format = selected.format;
    confidence = selected.confidence;
    warning = selected.warning;
    versionLabel = selected.label;
    reviewState = warning != null || confidence < lowConfidenceQuestionThreshold
        ? QuestionReviewState.needsAttention
        : confidence >= autoValidatedQuestionConfidence
        ? QuestionReviewState.reviewed
        : QuestionReviewState.inReview;
    alternateVersions[index] = previous;
  }

  Map<String, Object?> toJson(int position) => {
    'id': id,
    'position': position,
    'number': number,
    'statement': statement.trim(),
    'options': options.map((text) => {'text': text.trim()}).toList(),
    'correctIndex': correctIndex,
    'sourcePage': sourcePage,
    'sourcePages': sourcePages,
    'sourcePosition': sourcePosition,
    'instructions': instructions,
    'format': format.name,
    'subject': subject,
    'topic': topic,
    'language': language,
    'supportingMaterialIds': supportingMaterialIds,
    'confidence': confidence,
    'fieldConfidence': fieldConfidence,
    'warnings': warnings,
    'warning': warning,
    'reviewState': reviewState.name,
    'versionLabel': versionLabel,
    'alternateVersions': alternateVersions
        .map((version) => version.toJson())
        .toList(),
  };

  factory ImportedQuestion.fromJson(Map<String, dynamic> json) {
    final warning = json['warning'] as String?;
    final confidence = ((json['confidence'] as num?)?.toDouble() ?? 0)
        .clamp(0, 1)
        .toDouble();
    final number = json['number'] as int?;
    final page = json['sourcePage'] as int?;
    final statement = json['statement'] as String? ?? '';
    final fields = <String, double>{};
    final rawFields = json['fieldConfidence'];
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        if (entry.value is num) {
          fields[entry.key.toString()] = (entry.value as num)
              .toDouble()
              .clamp(0, 1)
              .toDouble();
        }
      }
    }
    return ImportedQuestion(
      id: json['id'] as String? ?? _stableQuestionId(number, page, statement),
      statement: statement,
      options: (json['options'] as List? ?? const [])
          .map(
            (option) => option is Map
                ? option['text']?.toString() ?? ''
                : option.toString(),
          )
          .toList(),
      correctIndex: json['correctIndex'] as int?,
      number: number,
      sourcePage: page,
      sourcePages: List<int>.from(
        json['sourcePages'] as List? ?? (page == null ? const [] : [page]),
      ),
      sourcePosition: json['sourcePosition'] as int?,
      instructions: json['instructions'] as String?,
      subject: json['subject'] as String?,
      topic: json['topic'] as String?,
      language: json['language'] as String?,
      supportingMaterialIds: List<String>.from(
        json['supportingMaterialIds'] as List? ?? const [],
      ),
      fieldConfidence: fields,
      warnings: List<String>.from(
        json['warnings'] as List? ?? (warning == null ? const [] : [warning]),
      ),
      format: QuestionFormat.values.firstWhere(
        (format) => format.name == json['format'],
        orElse: () => QuestionFormat.multipleChoice,
      ),
      confidence: confidence,
      warning: warning,
      reviewState: QuestionReviewState.values.firstWhere(
        (state) => state.name == json['reviewState'],
        orElse: () => QuestionReviewState.unreviewed,
      ),
      versionLabel: json['versionLabel'] as String? ?? 'Versão principal',
      alternateVersions: (json['alternateVersions'] as List? ?? const [])
          .map(
            (version) => ImportedQuestionVersion.fromJson(
              Map<String, dynamic>.from(version as Map),
            ),
          )
          .toList(),
    );
  }
}

String _stableQuestionId(int? number, int? page, String statement) {
  final fingerprint = sha256.convert(utf8.encode(statement.trim())).toString();
  return 'q-${page ?? 0}-${number ?? 0}-${fingerprint.substring(0, 16)}';
}

enum QuestionReviewState { unreviewed, inReview, reviewed, needsAttention }

const autoValidatedQuestionConfidence = .99;
const lowConfidenceQuestionThreshold = .80;

class ImportedQuestionVersion {
  const ImportedQuestionVersion({
    required this.label,
    required this.statement,
    required this.options,
    required this.correctIndex,
    required this.format,
    required this.confidence,
    required this.warning,
  });

  final String label;
  final String statement;
  final List<String> options;
  final int? correctIndex;
  final QuestionFormat format;
  final double confidence;
  final String? warning;

  factory ImportedQuestionVersion.fromJson(Map<String, dynamic> json) =>
      ImportedQuestionVersion(
        label: json['label'] as String? ?? 'Versão alternativa',
        statement: json['statement'] as String? ?? '',
        options: List<String>.from(json['options'] as List? ?? const []),
        correctIndex: json['correctIndex'] as int?,
        format: QuestionFormat.values.firstWhere(
          (format) => format.name == json['format'],
          orElse: () => QuestionFormat.unknown,
        ),
        confidence: ((json['confidence'] as num?)?.toDouble() ?? 0.5)
            .clamp(0, 1)
            .toDouble(),
        warning: json['warning'] as String?,
      );

  Map<String, Object?> toJson() => {
    'label': label,
    'statement': statement,
    'options': options,
    'correctIndex': correctIndex,
    'format': format.name,
    'confidence': confidence,
    'warning': warning,
  };
}

enum QuestionFormat { multipleChoice, trueFalse, assertion, openEnded, unknown }

class QuestionParser {
  const QuestionParser();

  List<ImportedQuestion> parse(String source) {
    final text = _normalize(source);
    if (text.trim().isEmpty) return const [];

    final lines = text.split('\n');
    final candidates = <_QuestionStart>[];
    final seenVariantsByNumber = <int, Set<String>>{};
    final candidateVariantLabels = <int, String>{};
    final sourcePagesByLine = <int, int>{};
    var currentVariantLabel = 'Versão principal';
    var inInstructions = false;
    var previousNumber = -1;
    int? variantLow;
    int? variantHigh;
    int? currentSourcePage;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final pageMarker = _pageMarker.firstMatch(line);
      if (pageMarker != null) {
        currentSourcePage = int.tryParse(pageMarker.group(1)!);
        continue;
      }
      if (currentSourcePage != null) sourcePagesByLine[i] = currentSourcePage;
      if (_startsAnswerKeySection(lines, i)) break;
      if (_isInstructionHeading(line)) {
        inInstructions = true;
        continue;
      }
      final sectionVariant = _languageVariantHeading(line);
      if (sectionVariant != null) {
        inInstructions = false;
        currentVariantLabel = sectionVariant;
        final range = _extendedVariantRange(lines, i, null, null);
        variantLow = range.$1;
        variantHigh = range.$2;
      } else if (_isMajorSectionHeading(line)) {
        inInstructions = false;
        currentVariantLabel = 'Versão principal';
        variantLow = null;
        variantHigh = null;
      } else if (currentVariantLabel != 'Versão principal') {
        final range = _extendedVariantRange(lines, i, variantLow, variantHigh);
        variantLow = range.$1;
        variantHigh = range.$2;
      }
      final hasFollowingOptions = _hasFollowingOptions(lines, i + 1);
      final trueFalseContext = _looksLikeTrueFalse(lines.take(i).join('\n'));
      final hasLeadingGap = i == 0 || lines[i - 1].trim().isEmpty;
      final candidate = _detectQuestionStart(
        line,
        previousNumber,
        lines: lines,
        lineIndex: i,
        hasFollowingOptions: hasFollowingOptions,
        trueFalseContext: trueFalseContext,
        hasLeadingGap: hasLeadingGap,
        seenVariantsByNumber: seenVariantsByNumber,
        currentVariantLabel: currentVariantLabel,
        variantLow: variantLow,
        variantHigh: variantHigh,
      );
      if (candidate == null) continue;
      if (inInstructions) {
        // The numbered commands that open a caderno are not questions. Only a
        // marker the board itself wrote, or a section title, ends that block.
        if (!candidate.explicit) continue;
        inInstructions = false;
      }

      // A numeric marker is much more trustworthy when the sequence is
      // coherent or the block eventually contains options.
      if (candidate.number != null) {
        if (_endsVariantTrack(
          number: candidate.number!,
          explicitMarker: candidate.explicit,
          label: currentVariantLabel,
          low: variantLow,
          high: variantHigh,
          seenVariantsByNumber: seenVariantsByNumber,
        )) {
          currentVariantLabel = 'Versão principal';
          variantLow = null;
          variantHigh = null;
        }
        previousNumber = candidate.number!;
        seenVariantsByNumber
            .putIfAbsent(candidate.number!, () => <String>{})
            .add(currentVariantLabel);
        candidateVariantLabels[i] = currentVariantLabel;
      }
      candidates.add(candidate.copyWith(lineIndex: i));
    }

    // A cover page is full of numbers — the booklet code, the colour of the
    // caderno, the day, the table of the answer sheet. When the board itself
    // writes “Questão 12”, that marker owns the number and every candidate the
    // scan inferred for it is noise from the pages around it.
    final explicitNumbers = <int, Set<String>>{};
    for (final candidate in candidates) {
      final number = candidate.number;
      if (number == null || !candidate.explicit) continue;
      explicitNumbers
          .putIfAbsent(number, () => <String>{})
          .add(
            candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal',
          );
    }
    candidates.removeWhere((candidate) {
      final number = candidate.number;
      if (number == null || candidate.explicit) return false;
      final label =
          candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal';
      return explicitNumbers[number]?.contains(label) == true;
    });

    final questions = <ImportedQuestion>[];
    var inheritedTrueFalse =
        candidates.isNotEmpty &&
        _looksLikeTrueFalse(lines.take(candidates.first.lineIndex).join('\n'));
    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final nextLine = i + 1 < candidates.length
          ? candidates[i + 1].lineIndex
          : lines.length;
      final candidateBlock = lines.sublist(candidate.lineIndex, nextLine);
      final sectionBoundary = candidateBlock.indexWhere(
        _isNonQuestionSectionBoundary,
      );
      final boundedBlock = candidateBlock
          .take(sectionBoundary < 0 ? candidateBlock.length : sectionBoundary)
          .toList(growable: false);
      final block = boundedBlock
          .where((line) => !_pageMarker.hasMatch(line))
          .join('\n')
          .trim();

      final parsed = _parseBlock(
        block,
        candidate,
        inheritedTrueFalse: inheritedTrueFalse,
      );
      if (parsed != null) {
        parsed.versionLabel =
            candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal';
        parsed.sourcePage = sourcePagesByLine[candidate.lineIndex];
        final sourcePageSet = <int>{?parsed.sourcePage};
        for (var offset = 0; offset < boundedBlock.length; offset++) {
          if (_pageMarker.hasMatch(boundedBlock[offset])) continue;
          final page = sourcePagesByLine[candidate.lineIndex + offset];
          if (page != null) sourcePageSet.add(page);
        }
        final sourcePages = sourcePageSet.toList()..sort();
        parsed.sourcePages
          ..clear()
          ..addAll(sourcePages);
        parsed.sourcePosition = candidate.lineIndex;
        parsed.language = parsed.versionLabel == 'Versão principal'
            ? null
            : parsed.versionLabel;
        parsed.id = _stableQuestionId(
          parsed.number,
          parsed.sourcePage,
          parsed.statement,
        );
        questions.add(parsed);
        inheritedTrueFalse = parsed.format == QuestionFormat.trueFalse;
      } else if (candidate.explicit) {
        inheritedTrueFalse = false;
      }
    }

    return _coalesceParallelNumberedVersions(questions);
  }

  /// Parses page-ordered text while retaining the original page for each
  /// question. A question that continues onto the next page keeps its start
  /// page and its complete text block.
  List<ImportedQuestion> parsePages(List<String> pages) => parse(
    [
      for (var index = 0; index < pages.length; index++)
        '\u0000PROVA_SOCIAL_PAGE_${index + 1}\u0000\n${pages[index]}',
    ].join('\n'),
  );

  static final RegExp _pageMarker = RegExp(
    r'^\u0000PROVA_SOCIAL_PAGE_(\d+)\u0000$',
  );

  String? _languageVariantHeading(String line) {
    final heading = line.trim();
    if (RegExp(
      r'^l[ií]ngua\s+espanhola\b',
      caseSensitive: false,
    ).hasMatch(heading)) {
      return 'Espanhol';
    }
    if (RegExp(
      r'^l[ií]ngua\s+inglesa\b',
      caseSensitive: false,
    ).hasMatch(heading)) {
      return 'Inglês';
    }
    if (RegExp(
      r'^l[ií]ngua\s+portuguesa\b',
      caseSensitive: false,
    ).hasMatch(heading)) {
      return 'Português';
    }
    return null;
  }

  /// The question range a line declares, either inline (“responder às
  /// questões 43 e 44”) or as its own label (“39 a 44.”). Sections of a
  /// parallel language track use these to state which numbers they cover.
  (int, int)? _rangeDeclaration(String line) {
    final inline = RegExp(
      r'(?:quest(?:ão|ões|oes|ao)|itens?)\s*(?:de|das|dos)?\s*(\d{1,4})\s*(?:a|até|to|hasta|e)\s*(\d{1,4})',
      caseSensitive: false,
    );
    final label = RegExp(
      r'^\s*(\d{1,4})\s*(?:a|até|to|hasta|e)\s*(\d{1,4})\s*[.:)]?\s*$',
      caseSensitive: false,
    );
    for (final pattern in [label, inline]) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final low = int.tryParse(match.group(1) ?? '');
      final high = int.tryParse(match.group(2) ?? '');
      if (low == null || high == null || high < low) continue;
      return (low, high);
    }
    return null;
  }

  /// The range an active language track accumulates: a heading declares its
  /// own range, the label on the next line belongs to it, and every later
  /// instruction widens it, because one language can be split into passages
  /// that each name their own numbers.
  (int?, int?) _extendedVariantRange(
    List<String> lines,
    int index,
    int? low,
    int? high,
  ) {
    (int?, int?) union((int, int)? range) {
      if (range == null) return (low, high);
      return (
        low == null ? range.$1 : (low < range.$1 ? low : range.$1),
        high == null ? range.$2 : (high > range.$2 ? high : range.$2),
      );
    }

    final merged = union(_rangeDeclaration(lines[index]));
    low = merged.$1;
    high = merged.$2;
    for (
      var offset = index + 1;
      offset <= index + 3 && offset < lines.length;
      offset++
    ) {
      final next = lines[offset];
      if (_pageMarker.hasMatch(next)) break;
      if (next.trim().isEmpty) continue;
      final mergedNext = union(_rangeDeclaration(next));
      low = mergedNext.$1;
      high = mergedNext.$2;
      break;
    }
    return (low, high);
  }

  bool _withinVariantRange(int? number, int? low, int? high) {
    if (low == null || high == null) return true;
    if (number == null) return false;
    return number >= low && number <= high;
  }

  /// A mirrored language track ends as soon as a marker leaves its declared
  /// range; without a range it ends when an inferred marker introduces a
  /// number that no other track published. An explicit marker such as
  /// “Questão 39” always belongs to the section that states it.
  bool _endsVariantTrack({
    required int number,
    required bool explicitMarker,
    required String label,
    required int? low,
    required int? high,
    required Map<int, Set<String>> seenVariantsByNumber,
  }) {
    if (label == 'Versão principal') return false;
    if (low != null && high != null) return number < low || number > high;
    if (explicitMarker) return false;
    return seenVariantsByNumber[number]?.any((other) => other != label) != true;
  }

  /// Boards number a caderno in one direction, so an inferred marker has to
  /// stay near the number already found. A page whose columns are read out of
  /// order (78, 80, 79) fits inside the slack; a stray measurement does not.
  static const int _numberingSlack = 5;

  bool _inNumberingSlack(int? number, int previousNumber) {
    if (number == null) return false;
    if (previousNumber < 0) return true;
    return (number - previousNumber).abs() <= _numberingSlack;
  }

  /// Whether the lines above a bare number are other bare numbers, which is
  /// the shape of a numeric table column and never of a question marker.
  bool _numericRunBefore(List<String> lines, int lineIndex) {
    final bare = RegExp(r'^\s*\d{1,4}\s*$');
    var checked = 0;
    var values = 0;
    for (var index = lineIndex - 1; index >= 0 && checked < 4; index--) {
      final line = lines[index];
      if (line.trim().isEmpty || _pageMarker.hasMatch(line)) continue;
      checked++;
      if (bare.hasMatch(line)) values++;
    }
    return values >= 2;
  }

  bool _isMajorSectionHeading(String line) {
    final heading = line.trim();
    if (heading.length < 8 || heading != heading.toUpperCase()) return false;
    return RegExp(r'[A-ZÁÉÍÓÚÂÊÔÃÕÇ]{3}').hasMatch(heading);
  }

  /// Sections printed after the last question. The answer key belongs here:
  /// without the cut its grid is read as the tail of the final statement.
  bool _isNonQuestionSectionBoundary(String line) => RegExp(
    r'^(?:REDA[CÇ][AÃ]O|PROPOSTA DE REDA[CÇ][AÃ]O|RASCUNHO|FOLHA DE RASCUNHO'
    r'|CLASSIFICA[CÇ][AÃ]O PERI[ÓO]DICA|TABELA PERI[ÓO]DICA|FOLHA DE RESPOSTAS'
    r'|GABARITO|CHAVE DE RESPOSTAS|RESPOSTAS OFICIAIS'
    r'|RESULTADO (?:PRELIMINAR|DEFINITIVO))\b',
    caseSensitive: false,
  ).hasMatch(line.trim());

  static final RegExp _answerKeyTitle = RegExp(
    r'^(?:gabarito|chave\s+de\s+(?:respostas?|gabarito)'
    r'|respostas?\s+(?:oficiais?|do\s+candidato)'
    r'|resultado\s+(?:preliminar|definitivo)|answer\s+key)\b',
    caseSensitive: false,
  );

  static final RegExp _keyPairLine = RegExp(
    r'\d{1,3}\s*[).:\-–—/|\]]?\s*\(?\s*'
    r'(?:[A-Ha-hVvFf]|cert[oa]|errad[oa]|verdadeir[oa]|fals[oa])\b',
    caseSensitive: false,
  );

  static final RegExp _instructionHeading = RegExp(
    r'^(?:leia\s+(?:com\s+)?(?:atentamente\s+)?(?:as\s+|a\s+)?(?:instru|procedimento)'
    r'|instru(?:ç|c)(?:õ|o)es|procedimentos|comandos\s+para\s+(?:a\s+)?prova'
    r'|orienta(?:ç|c)(?:õ|o)es\s+(?:gerais|da\s+prova))',
    caseSensitive: false,
  );

  /// The page of commands every caderno prints before the first question. Its
  /// items are numbered one, two, three, and each of them is shaped like a
  /// question — they are the most common source of invented questions.
  bool _isInstructionHeading(String line) {
    final text = line.trim();
    if (text.isEmpty || text.length > 70) return false;
    if (!_instructionHeading.hasMatch(text)) return false;
    return text.endsWith(':') || text == text.toUpperCase();
  }

  /// Whether the questionnaire ends here. The printed key is a list of
  /// number-and-letter lines, and each of them is shaped exactly like a
  /// one-line question, so the scan has to stop before it invents questions.
  /// The title alone is not enough — a notice that “o gabarito será divulgado”
  /// appears in the instructions — the lines under it have to be pairs.
  bool _startsAnswerKeySection(List<String> lines, int index) {
    final title = lines[index].trim();
    if (!_answerKeyTitle.hasMatch(title)) return false;
    var checked = 0;
    var paired = 0;
    for (var i = index + 1; i < lines.length && checked < 6; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || _pageMarker.hasMatch(line)) continue;
      checked++;
      if (line.length > 120) continue;
      if (_keyPairLine.hasMatch(line)) paired++;
    }
    if (paired < 2) return false;
    return paired >= (checked * .7).ceil();
  }

  List<ImportedQuestion> _coalesceParallelNumberedVersions(
    List<ImportedQuestion> questions,
  ) {
    final counts = <int, int>{};
    for (final question in questions) {
      final number = question.number;
      if (number != null) {
        counts.update(number, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final repeated =
        counts.entries
            .where((entry) => entry.value > 1)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    // Repeated numbering alone is ambiguous. Coalesce only a run of at least
    // three consecutive repeated IDs, the common signature of parallel
    // language/booklet tracks. Isolated duplicates remain visible to QA.
    final parallelNumbers = <int>{};
    var run = <int>[];
    for (final number in repeated) {
      if (run.isEmpty || number == run.last + 1) {
        run.add(number);
      } else {
        if (run.length >= 3) parallelNumbers.addAll(run);
        run = [number];
      }
    }
    if (run.length >= 3) parallelNumbers.addAll(run);
    if (parallelNumbers.isEmpty) return questions;

    final primaryByNumber = <int, ImportedQuestion>{};
    final result = <ImportedQuestion>[];
    for (final question in questions) {
      final number = question.number;
      if (number == null || !parallelNumbers.contains(number)) {
        result.add(question);
        continue;
      }
      final primary = primaryByNumber[number];
      if (primary == null) {
        primaryByNumber[number] = question;
        result.add(question);
        continue;
      }
      primary.alternateVersions.add(
        ImportedQuestionVersion(
          label: question.versionLabel == primary.versionLabel
              ? 'Versão alternativa ${primary.alternateVersions.length + 1}'
              : question.versionLabel,
          statement: question.statement,
          options: List.unmodifiable(question.options),
          correctIndex: question.correctIndex,
          format: question.format,
          confidence: question.confidence,
          warning: question.warning,
        ),
      );
    }
    return result;
  }

  /// Parses independently extracted PDF columns/pages and merges them in the
  /// order supplied by the PDF/layout extractor. This is intentionally kept
  /// separate from [parse], because plain text has no reliable x/y geometry.
  /// A PDF extractor that exposes columns can therefore avoid interleaving
  /// left/right content before this parser sees it.
  List<ImportedQuestion> parseColumns(Iterable<String> columns) {
    final result = <ImportedQuestion>[];
    for (final column in columns) {
      result.addAll(parse(column));
    }
    return result;
  }

  bool _hasFollowingOptions(List<String> lines, int start) {
    if (start >= lines.length) return false;
    final followingLines = <String>[];
    final end = (start + 80).clamp(0, lines.length);
    for (var index = start; index < end; index++) {
      if (index > start && RegExp(r'^\s*\d{1,3}\s*$').hasMatch(lines[index])) {
        break;
      }
      followingLines.add(lines[index]);
      final scan = _findOptionMarkers(followingLines.join('\n'));
      if (scan.markers.length >= 2 || scan.rawMarkerCount >= 2) return true;
    }
    return false;
  }

  bool _hasQuestionBodyAfter(List<String> lines, int lineIndex) {
    for (var index = lineIndex + 1; index < lines.length; index++) {
      final candidate = lines[index].trim();
      if (candidate.isEmpty) continue;
      if (RegExp(r'^\d{1,3}$').hasMatch(candidate) ||
          _findOptionMarkers(candidate).rawMarkerCount > 0) {
        return false;
      }
      return candidate.length >= 4;
    }
    return false;
  }

  String _normalize(String source) => ExamTextNormalizer.normalize(source);

  _QuestionStart? _detectQuestionStart(
    String line,
    int previousNumber, {
    required List<String> lines,
    required int lineIndex,
    required bool hasFollowingOptions,
    required bool trueFalseContext,
    required bool hasLeadingGap,
    required Map<int, Set<String>> seenVariantsByNumber,
    required String currentVariantLabel,
    required int? variantLow,
    required int? variantHigh,
  }) {
    final explicit = RegExp(
      r'^\s*(?:quest(?:ão|ao)|q(?:uestão|uestao)?\.?)[ \t]*(?:n[º°.]?[ \t]*)?(\d{1,4})\s*(?:[.:)\-]+)?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (explicit != null) {
      // “Q 12 · Q” is the charge Q12 of a physics formula, not the compact
      // “Q12” the boards write: a bare letter, a space, and no marker
      // punctuation after the number. Such a start is only believed when it
      // continues the numbering of the caderno.
      final number = int.tryParse(explicit.group(1)!);
      final floatingLetter =
          RegExp(
            r'^\s*[Qq]\.?[ \t]+(?:n[º°.]?[ \t]*)?\d{1,4}(?!\s*[.:)\-–—])',
            caseSensitive: false,
          ).hasMatch(line) &&
          !RegExp(r'^\s*quest', caseSensitive: false).hasMatch(line);
      if (floatingLetter && !_inNumberingSlack(number, previousNumber)) {
        return null;
      }
      return _QuestionStart(
        lineIndex: -1,
        number: number,
        content: explicit.group(2)?.trim() ?? '',
        confidence: 1,
        explicit: true,
      );
    }

    final ordinal = RegExp(
      r'^\s*(\d{1,4})\s*[ªº°]\s*quest(?:ão|ao)\s*[:.\-]?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (ordinal != null) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(ordinal.group(1)!),
        content: ordinal.group(2)?.trim() ?? '',
        confidence: 1,
        explicit: true,
      );
    }

    final compact = RegExp(
      r'^\s*Q\s*(\d{1,4})\s*[.:)\-]?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (compact != null) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(compact.group(1)!),
        content: compact.group(2)?.trim() ?? '',
        confidence: .98,
        explicit: true,
      );
    }

    // Section labels such as “39 a 44” and “Questions 39 to 44” are ranges,
    // not question starts. They otherwise look sequential and can swallow the
    // passage that precedes a language-specific question track.
    if (RegExp(
      r'^\s*\d{1,4}\s+(?:a|até|to|through|hasta)\s+\d{1,4}[.:)]?\s*$',
      caseSensitive: false,
    ).hasMatch(line)) {
      return null;
    }

    final bareNumber = RegExp(r'^\s*(\d{1,4})[.)]?\s*$').firstMatch(line);
    final bareQuestionNumber = int.tryParse(bareNumber?.group(1) ?? '');
    final followsQuestionNumber =
        bareQuestionNumber != null && bareQuestionNumber == previousNumber + 1;
    final hasQuestionBody = _hasQuestionBodyAfter(lines, lineIndex);
    // A parallel language track mirrors numbers another track already
    // published, and it covers only the range its heading declares.
    final mirrorsOtherVariant =
        currentVariantLabel != 'Versão principal' &&
        _withinVariantRange(bareQuestionNumber, variantLow, variantHigh) &&
        seenVariantsByNumber[bareQuestionNumber]?.any(
              (label) => label != currentVariantLabel,
            ) ==
            true;
    // Values of a data table also occupy their own line. Unlike a marker,
    // they keep other bare numbers stacked just above them.
    final isTableValue =
        !followsQuestionNumber && _numericRunBefore(lines, lineIndex);
    if (bareNumber != null &&
        !isTableValue &&
        ((followsQuestionNumber && (hasQuestionBody || hasFollowingOptions)) ||
            (hasFollowingOptions &&
                (previousNumber < 0 ||
                    hasLeadingGap ||
                    mirrorsOtherVariant ||
                    _inNumberingSlack(bareQuestionNumber, previousNumber))))) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(bareNumber.group(1)!),
        content: '',
        confidence: followsQuestionNumber || hasFollowingOptions ? .94 : .86,
        explicit: false,
      );
    }

    // Numeric markers are deliberately conservative. This avoids turning
    // dates, percentages, enumerations, measurements and years into questions.
    final numeric = RegExp(r'^\s*(\d{1,4})(?:\s*[.):-]\s*|\s+)(.*)$')
        .firstMatch(line);
    if (numeric == null) return null;

    final number = int.tryParse(numeric.group(1)!);
    if (number == null || number > 9999) return null;
    final rest = numeric.group(2)?.trim() ?? '';

    final sequential =
        previousNumber >= 0 &&
        (number == previousNumber + 1 || (previousNumber == 0 && number == 1));
    final hasQuestionPunctuation =
        rest.contains('?') ||
        RegExp(
          r'^(?:qual|quais|como|por que|porque|assinale|considere|analise|leia|sobre|julgue)\b',
          caseSensitive: false,
        ).hasMatch(rest);

    final hasBlockEvidence =
        hasFollowingOptions && (previousNumber < 0 || hasLeadingGap);
    if (!sequential &&
        !hasQuestionPunctuation &&
        !hasBlockEvidence &&
        !trueFalseContext) {
      return null;
    }
    // A caderno numbers its questions in one direction, so a marker that does
    // not continue the sequence needs the board's own label to be believed.
    // Without this, the “12” a formula leaves on its own line becomes a
    // question and swallows the two printed around it.
    if (!sequential && !_inNumberingSlack(number, previousNumber)) {
      return null;
    }

    return _QuestionStart(
      lineIndex: -1,
      number: number,
      content: rest,
      confidence: sequential ? .94 : .78,
      explicit: false,
    );
  }

  ImportedQuestion? _parseBlock(
    String block,
    _QuestionStart start, {
    bool inheritedTrueFalse = false,
  }) {
    var content = start.content.isEmpty
        ? _removeMarker(block, start)
        : _joinContent(block, start.content);
    if (content.trim().length < 4) return _uncertainQuestion(content, start);

    content = _reattachGluedTrailingOption(content);
    final optionScan = _findOptionMarkers(content);
    if (optionScan.markers.length >= 2) {
      final parsed = _parseOptions(content, optionScan.markers);
      if (parsed == null) return _uncertainQuestion(content, start);
      final statement = _cleanStatement(parsed.statement);
      final missingOptionText = parsed.options.every(
        (option) => option.isEmpty,
      );
      // A two-column caderno can print the command in the neighbouring column,
      // leaving the block that carries the marker with nothing but the
      // alternatives. Those are still worth keeping: the reviewer completes the
      // stem instead of losing a question with no structure at all.
      final stemIsMissing =
          !_plausibleStatement(statement) &&
          parsed.options.length >= 4 &&
          !missingOptionText;
      if (!_plausibleStatement(statement) && !stemIsMissing) {
        return _uncertainQuestion(content, start);
      }
      final warnings = <String>[];
      if (stemIsMissing) {
        warnings.add(
          'Enunciado não foi separado das alternativas; revisar na página de origem.',
        );
      }
      if (parsed.options.length < 4) {
        warnings.add(
          'Foram detectadas ${parsed.options.length} alternativas; revisar estrutura.',
        );
      } else if (parsed.options.length > 5) {
        warnings.add(
          'Estrutura incomum: ${parsed.options.length} alternativas preservadas.',
        );
      }
      if (optionScan.hasIncoherentMarkers) {
        warnings.add(
          'Marcadores de alternativas incompletos ou fora de ordem.',
        );
      }
      if (missingOptionText) {
        warnings.add(
          'Alternativas identificadas, mas o conteúdo visual não foi extraído; revisar na página de origem.',
        );
      }
      return ImportedQuestion(
        statement: statement,
        options: parsed.options,
        number: start.number,
        format: QuestionFormat.multipleChoice,
        confidence: missingOptionText
            ? .65
            : stemIsMissing
            ? .6
            : _optionConfidence(
                start,
                parsed.options.length,
                hasIncoherentMarkers: optionScan.hasIncoherentMarkers,
              ),
        warning: warnings.isEmpty ? null : warnings.join(' '),
      );
    }

    if (_hasJudgementMarks(content) ||
        _looksLikeTrueFalse(content) ||
        inheritedTrueFalse) {
      final statement = _cleanTrueFalseStatement(content);
      if (statement.length < 8) return _uncertainQuestion(statement, start);
      return ImportedQuestion(
        statement: statement,
        options: const ['CERTO', 'ERRADO'],
        number: start.number,
        format: QuestionFormat.trueFalse,
        confidence: .9,
      );
    }

    // Assertion-style blocks may have a command but no A-E alternatives.
    if (_looksLikeAssertion(content)) {
      return ImportedQuestion(
        statement: _cleanStatement(content),
        options: const [],
        number: start.number,
        format: QuestionFormat.assertion,
        confidence: .72,
        warning: 'Questão sem alternativas detectadas; revisar importação.',
      );
    }

    if (_looksLikeOpenEnded(content)) {
      return ImportedQuestion(
        statement: _cleanStatement(content),
        options: const [],
        number: start.number,
        format: QuestionFormat.openEnded,
        confidence: .7,
        warning: 'Questão discursiva sem alternativas; revisar resposta esperada e critérios.',
      );
    }

    return _uncertainQuestion(content, start);
  }

  ImportedQuestion _uncertainQuestion(String content, _QuestionStart start) {
    final statement = _cleanStatement(content.trim());
    return ImportedQuestion(
      statement: statement,
      options: const [],
      number: start.number,
      format: QuestionFormat.unknown,
      confidence: (start.confidence * .55).clamp(0, 1).toDouble(),
      warning: 'Estrutura não reconhecida completamente; revisar questão e alternativas.',
    );
  }

  String _joinContent(String block, String firstLineContent) {
    final lines = block.split('\n');
    if (lines.isEmpty) return firstLineContent;
    lines[0] = firstLineContent;
    return lines.join('\n').trim();
  }

  String _removeMarker(String block, _QuestionStart start) {
    final lines = block.split('\n');
    if (lines.isNotEmpty) lines.removeAt(0);
    return lines.join('\n').trim();
  }

  _OptionScan _findOptionMarkers(String block) {
    final result = <_OptionMarker>[];
    final lines = block.split('\n');
    var offset = 0;

    for (final line in lines) {
      // Unwrapped labels require punctuation so ordinary prose like "A questão"
      // is not mistaken for an alternative. Parenthesized/bracketed and
      // marker-only labels remain supported for image-based alternatives.
      final wrapped = RegExp(
        r'^\s*(?:\(([A-Z])\)|\[([A-Z])\])\s*(?:[.):])?\s*(.*?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final unwrapped = RegExp(
        r'^\s*([A-Z])\s*[.):]\s*(.*?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final markerOnly = RegExp(
        r'^\s*([A-Z])\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final unwrappedText = RegExp(
        r'^\s*([A-Z])\s+(.+?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final letter =
          wrapped?.group(1) ??
          wrapped?.group(2) ??
          unwrapped?.group(1) ??
          markerOnly?.group(1) ??
          unwrappedText?.group(1);
      final optionText =
          wrapped?.group(3) ??
          unwrapped?.group(2) ??
          unwrappedText?.group(2) ??
          '';
      final markerMatch = wrapped ?? unwrapped ?? markerOnly ?? unwrappedText;
      if (letter != null && markerMatch != null) {
        final normalizedLetter = letter.toUpperCase();
        final contentStart = optionText.isEmpty
            ? line.length
            : line.indexOf(optionText);
        result.add(
          _OptionMarker(
            start: offset,
            contentStart: offset + contentStart,
            letter: normalizedLetter,
            text: optionText.trim(),
            requiresSequence: unwrappedText != null,
          ),
        );
      }
      offset += line.length + 1;
    }

    final sequenceFiltered = <_OptionMarker>[];
    var unwrappedRun = <_OptionMarker>[];
    void flushUnwrappedRun() {
      if (unwrappedRun.length >= 3) sequenceFiltered.addAll(unwrappedRun);
      unwrappedRun = [];
    }

    for (final marker in result) {
      if (!marker.requiresSequence) {
        flushUnwrappedRun();
        sequenceFiltered.add(marker);
        continue;
      }
      if (unwrappedRun.isNotEmpty &&
          marker.letter.codeUnitAt(0) !=
              unwrappedRun.last.letter.codeUnitAt(0) + 1) {
        flushUnwrappedRun();
      }
      unwrappedRun.add(marker);
    }
    flushUnwrappedRun();
    result
      ..clear()
      ..addAll(sequenceFiltered);

    // Boards that print “A denunciar …” with no punctuation, and text layers
    // that return the whole list on one line, leave the markers inside the
    // statement. Look for them there whenever the line scan came up short.
    if (result.length < 5) {
      final inline = _inlineMarkers(block);
      if (inline.length > result.length) {
        result
          ..clear()
          ..addAll(inline);
      }
    }

    final coherent = _coherentOptions(result);
    var expectedLabel = 'A'.codeUnitAt(0);
    final hasCompleteFilledSequence =
        coherent.length >= 4 &&
        coherent.first.letter == 'A' &&
        result
            .where((marker) => !coherent.contains(marker))
            .every((marker) => marker.text.isEmpty) &&
        coherent.every((marker) {
          final complete =
              marker.text.isNotEmpty &&
              marker.letter.codeUnitAt(0) == expectedLabel;
          expectedLabel++;
          return complete;
        });
    expectedLabel = 'A'.codeUnitAt(0);
    final hasLabelGap =
        coherent.any((marker) {
          final label = marker.letter.codeUnitAt(0);
          final isGap = label != expectedLabel;
          expectedLabel = label + 1;
          return isGap;
        }) ||
        (coherent.isNotEmpty && coherent.first.letter != 'A');
    return _OptionScan(
      markers: coherent,
      rawMarkerCount: result.length,
      hasIncoherentMarkers:
          !hasCompleteFilledSequence &&
          (coherent.length != result.length || hasLabelGap),
    );
  }

  /// Markers found inside a run of text instead of at the start of a line.
  ///
  /// Punctuation after the letter is enough evidence. A bare letter only is,
  /// because “A” opens sentences and “E” joins clauses, so the bare scan keeps
  /// the longest stretch that walks A, B, C, D in order and throws it away when
  /// fewer than four alternatives answer to it.
  List<_OptionMarker> _inlineMarkers(String block) {
    final punctuated = RegExp(
      r'(?:^|\s)(?:\(([A-Z])\)|([A-Z]))\s*[.):\-–]\s+',
      caseSensitive: false,
    ).allMatches(block).toList();
    if (punctuated.length >= 2) {
      return punctuated
          .map(
            (match) => _OptionMarker(
              start: match.start,
              contentStart: match.end,
              letter: (match.group(1) ?? match.group(2)!).toUpperCase(),
              text: '',
            ),
          )
          .toList();
    }

    final bare = RegExp(r'(?:^|\s)([A-E])\s+\S').allMatches(block).toList();
    var best = <RegExpMatch>[];
    var run = <RegExpMatch>[];
    for (final match in bare) {
      final letter = match.group(1)!.codeUnitAt(0);
      if (run.isEmpty) {
        if (letter == 'A'.codeUnitAt(0)) run = [match];
        continue;
      }
      if (letter == run.last.group(1)!.codeUnitAt(0) + 1) {
        run.add(match);
      } else {
        if (run.length > best.length) best = run;
        run = letter == 'A'.codeUnitAt(0) ? [match] : <RegExpMatch>[];
      }
    }
    if (run.length > best.length) best = run;
    if (best.length < 4) return const [];
    return best
        .map(
          (match) => _OptionMarker(
            start: match.start,
            contentStart: match.end - 1,
            letter: match.group(1)!,
            text: '',
          ),
        )
        .toList();
  }

  /// A justified column sometimes ends the command on the same line as the
  /// last alternative: “Questão 38 … o(a) E fragmento …”. The line scan then
  /// reads A to D and the letter that closes the list is swallowed by the
  /// statement. Move that tail back to the end of the block so the normal
  /// marker rules can see it as an alternative again.
  String _reattachGluedTrailingOption(String block) {
    final lines = block.split('\n');
    final run = <String>[];
    for (final line in lines) {
      final match = RegExp(r'^([A-E])\s+\S').firstMatch(line.trim());
      if (match == null) continue;
      final letter = match.group(1)!;
      if (run.isEmpty) {
        if (letter == 'A') run.add(letter);
      } else if (letter.codeUnitAt(0) == run.last.codeUnitAt(0) + 1) {
        run.add(letter);
      }
    }
    if (run.length < 3 || run.last == 'E') return block;
    final missing = String.fromCharCode(run.last.codeUnitAt(0) + 1);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('$missing ')) continue;
      final glued = RegExp(r'\s' + missing + r'\s+\S').firstMatch(line);
      if (glued == null) continue;
      final start = glued.start;
      final tail = line.substring(start).trim();
      final head = line.substring(0, start).trimRight();
      if (head.isEmpty || tail.length < 8) continue;
      lines[i] = head;
      lines.add(tail);
      return lines.join('\n');
    }
    return block;
  }

  List<_OptionMarker> _coherentOptions(List<_OptionMarker> markers) {
    if (markers.length < 2) return const [];
    final completeFilledRuns = <List<_OptionMarker>>[];
    var filledRun = <_OptionMarker>[];
    for (final marker in markers) {
      final isNext =
          filledRun.isNotEmpty &&
          marker.letter.codeUnitAt(0) ==
              filledRun.last.letter.codeUnitAt(0) + 1;
      if (marker.text.isNotEmpty &&
          ((filledRun.isEmpty && marker.letter == 'A') || isNext)) {
        filledRun.add(marker);
      } else {
        if (filledRun.length >= 4) completeFilledRuns.add(filledRun);
        filledRun = marker.text.isNotEmpty && marker.letter == 'A'
            ? [marker]
            : <_OptionMarker>[];
      }
    }
    if (filledRun.length >= 4) completeFilledRuns.add(filledRun);
    if (completeFilledRuns.isNotEmpty) {
      return completeFilledRuns.reduce(
        (best, candidate) => candidate.length >= best.length ? candidate : best,
      );
    }

    final output = <_OptionMarker>[markers.first];
    var previous = markers.first.letter.codeUnitAt(0);
    for (var i = 1; i < markers.length; i++) {
      final code = markers[i].letter.codeUnitAt(0);
      if (code == 'A'.codeUnitAt(0)) {
        if (previous >= 'E'.codeUnitAt(0)) {
          output.add(markers[i]);
          previous = code;
        }
      } else if (code > previous) {
        output.add(markers[i]);
        previous = code;
      }
    }
    return output.length >= 2 ? output : const [];
  }

  _ParsedOptions? _parseOptions(String block, List<_OptionMarker> markers) {
    final options = <String>[];
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      final end = i + 1 < markers.length ? markers[i + 1].start : block.length;
      var text = block.substring(marker.contentStart, end).trim();
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      // AOCP and Instituto MAIS write “A - alternativa”. The dash is the label's
      // punctuation, not part of the answer, while “-19.” keeps its sign.
      text = text.replaceFirst(RegExp(r'^[-–—]\s+'), '').trim();
      options.add(text);
    }
    if (options.length < 2) return null;

    final statementEnd = markers.first.start;
    final statement = block.substring(0, statementEnd).trim();
    return _ParsedOptions(statement: statement, options: options);
  }

  double _optionConfidence(
    _QuestionStart start,
    int count, {
    required bool hasIncoherentMarkers,
  }) {
    var score = start.confidence;
    if (count >= 4 && count <= 5) score += .05;
    if (count < 4 || count > 5) score -= .1;
    if (hasIncoherentMarkers) score -= .15;
    return score.clamp(0, 1).toDouble();
  }

  bool _plausibleStatement(String statement) {
    if (statement.length < 8) return false;
    if (RegExp(r'^\d+(?:[.,]\d+)?\s*%?$').hasMatch(statement)) return false;
    return true;
  }

  /// CEBRASPE-style items carry their own answer boxes: “1. ( ) O servidor…”.
  /// The empty parens, or the “(C) (E)” pair printed side by side, say more
  /// about the format than any keyword in the command, which may sit pages
  /// away from the item.
  bool _hasJudgementMarks(String content) =>
      _judgementMarks.allMatches(content).isNotEmpty &&
      !_hasOptionPunctuation(content);

  static final RegExp _judgementMarks = RegExp(
    r'(?:\b[CE]\s+)?\(\s*\)(?:\s+[CE]\s+\(\s*\))?'
    r'|\(\s*[cC]\s*\)\s*\(\s*[eE]\s*\)'
    r'|\(\s*[eE]\s*\)\s*\(\s*[cC]\s*\)',
  );

  /// A stem with a real alternative list is never a judgement item, however
  /// many empty parentheses the command uses for blanks to fill.
  bool _hasOptionPunctuation(String content) {
    final markers = RegExp(
      r'(?:(?:^|\s)(?:\(([A-F])\)|([A-F]))\s*[.):])',
      caseSensitive: false,
    ).allMatches(content);
    final letters = markers
        .map((match) => (match.group(1) ?? match.group(2)!).toUpperCase())
        .toSet();
    return letters.length >= 2 && letters.contains('A');
  }

  bool _looksLikeTrueFalse(String content) {
    final lower = content.toLowerCase();
    return RegExp(
          r'(julgue|julgar|certo ou errado|certo/errado|verdadeiro ou falso|v ou f|verdadeiro/falso)',
        ).hasMatch(lower) ||
        RegExp(r'\b(certo|errado)\b').allMatches(lower).length >= 2;
  }

  String _cleanTrueFalseStatement(String content) {
    var statement = content
        .replaceFirst(
          RegExp(
            r'^.*?(?:julgue os itens[^.]*\.|julgue o item[^.]*\.)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(_judgementMarks, ' ')
        .trim();
    // The item number lives in the marker, so a leftover “2.” in the body is
    // the answer box of the previous line, not part of the sentence.
    statement = statement.replaceFirst(RegExp(r'^\d{1,3}[).:]\s*'), '');
    if (_judgementMarks.hasMatch(statement)) {
      statement = statement
          .replaceAll(RegExp(r'\s*\(\s*\)\s*'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }
    return statement;
  }

  bool _looksLikeAssertion(String content) {
    final lower = content.toLowerCase();
    return lower.contains('assertiva:') ||
        lower.contains('situação hipotética:') ||
        lower.contains('situação hipotetica:');
  }

  bool _looksLikeOpenEnded(String content) => RegExp(
    r'\b(redija|discorra|elabore|descreva|explique|responda|justifique)\b',
    caseSensitive: false,
  ).hasMatch(content);

  String _cleanStatement(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([,.;:!?])'), r'\1')
        .trim();
  }
}

class _QuestionStart {
  const _QuestionStart({
    required this.lineIndex,
    required this.number,
    required this.content,
    required this.confidence,
    required this.explicit,
  });

  final int lineIndex;
  final int? number;
  final String content;
  final double confidence;
  final bool explicit;

  _QuestionStart copyWith({int? lineIndex}) => _QuestionStart(
    lineIndex: lineIndex ?? this.lineIndex,
    number: number,
    content: content,
    confidence: confidence,
    explicit: explicit,
  );
}

class _OptionMarker {
  const _OptionMarker({
    required this.start,
    required this.contentStart,
    required this.letter,
    required this.text,
    this.requiresSequence = false,
  });

  final int start;
  final int contentStart;
  final String letter;
  final String text;
  final bool requiresSequence;
}

class _ParsedOptions {
  const _ParsedOptions({required this.statement, required this.options});

  final String statement;
  final List<String> options;
}

class _OptionScan {
  const _OptionScan({
    required this.markers,
    required this.rawMarkerCount,
    required this.hasIncoherentMarkers,
  });

  final List<_OptionMarker> markers;
  final int rawMarkerCount;
  final bool hasIncoherentMarkers;
}

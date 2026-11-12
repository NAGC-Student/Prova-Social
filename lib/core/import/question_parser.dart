import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'exam_layout_profile.dart';
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
    Map<int, String>? optionImageBase64,
    Map<String, double>? fieldConfidence,
    List<String>? warnings,
    this.format = QuestionFormat.multipleChoice,
    this.confidence = 0,
    this.warning,
    this.hasVisualOptions = false,
    QuestionReviewState? reviewState,
    this.versionLabel = 'Versão principal',
    List<ImportedQuestionVersion>? alternateVersions,
    this.explanation,
    this.expectedAnswer,
    this.rubric,
    this.canonicalUrl,
    this.source,
    this.version = 1,
    this.contentHash,
  }) : id = id ?? _stableQuestionId(number, sourcePage, statement),
       sourcePages =
           sourcePages ?? (sourcePage == null ? <int>[] : <int>[sourcePage]),
       supportingMaterialIds = supportingMaterialIds ?? <String>[],
       optionImageBase64 = optionImageBase64 ?? <int, String>{},
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

  /// JPEG crops for answer choices rendered as diagrams or formula images.
  /// Keys are zero-based choice positions; values are Base64 encoded bytes.
  Map<int, String> optionImageBase64;
  final Map<String, double> fieldConfidence;
  final List<String> warnings;
  QuestionFormat format;
  double confidence;
  String? warning;

  /// True when at least one answer choice is present in the source page image
  /// but could not be represented as text by the PDF text layer.
  bool hasVisualOptions;
  QuestionReviewState reviewState;
  String versionLabel;
  final List<ImportedQuestionVersion> alternateVersions;

  /// Explanation for the correct answer (shown in review)
  String? explanation;

  /// Expected answer for discursive questions
  String? expectedAnswer;

  /// Rubric/criteria for scoring discursive questions
  String? rubric;

  /// Canonical URL for this question
  String? canonicalUrl;

  /// Source/provenance information
  String? source;

  /// Version number of this question
  int version;

  /// SHA-256 hash of question content for versioning
  String? contentHash;

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
    'optionImageBase64': {
      for (final entry in optionImageBase64.entries)
        entry.key.toString(): entry.value,
    },
    'confidence': confidence,
    'fieldConfidence': fieldConfidence,
    'warnings': warnings,
    'warning': warning,
    'hasVisualOptions': hasVisualOptions,
    'reviewState': reviewState.name,
    'versionLabel': versionLabel,
    'alternateVersions': alternateVersions
        .map((version) => version.toJson())
        .toList(),
    'explanation': explanation?.trim(),
    'expectedAnswer': expectedAnswer?.trim(),
    'rubric': rubric?.trim(),
    'canonicalUrl': canonicalUrl?.trim(),
    'source': source?.trim(),
    'version': version,
    'contentHash': contentHash,
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
    final optionImages = <int, String>{};
    final rawOptionImages = json['optionImageBase64'];
    if (rawOptionImages is Map) {
      for (final entry in rawOptionImages.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index != null && entry.value is String) {
          optionImages[index] = entry.value as String;
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
      optionImageBase64: optionImages,
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
      hasVisualOptions: json['hasVisualOptions'] as bool? ?? false,
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
      explanation: json['explanation'] as String?,
      expectedAnswer: json['expectedAnswer'] as String?,
      rubric: json['rubric'] as String?,
      canonicalUrl: json['canonicalUrl'] as String?,
      source: json['source'] as String?,
      version: json['version'] as int? ?? 1,
      contentHash: json['contentHash'] as String?,
    );
  }
}

String _stableQuestionId(int? number, int? page, String statement) {
  final fingerprint = sha256.convert(utf8.encode(statement.trim())).toString();
  return 'q-${page ?? 0}-${number ?? 0}-${fingerprint.substring(0, 16)}';
}

enum QuestionReviewState { unreviewed, inReview, reviewed, needsAttention }

enum QuestionFeasibility { feasible, fixable, notFeasible }

const autoValidatedQuestionConfidence = .99;
const lowConfidenceQuestionThreshold = .80;

extension QuestionFeasibilityExtension on ImportedQuestion {
  QuestionFeasibility get feasibility {
    if (warning != null) return QuestionFeasibility.fixable;
    if (format == QuestionFormat.unknown)
      return QuestionFeasibility.notFeasible;
    if (statement.trim().length < 2) return QuestionFeasibility.notFeasible;
    if (format != QuestionFormat.openEnded) {
      if (options.length < 2) return QuestionFeasibility.notFeasible;
      if (!hasVisualOptions && options.any((o) => o.trim().isEmpty)) {
        return QuestionFeasibility.fixable;
      }
      if (correctIndex == null ||
          correctIndex! < 0 ||
          correctIndex! >= options.length) {
        return QuestionFeasibility.fixable;
      }
    }
    if (format == QuestionFormat.openEnded && correctIndex != null) {
      return QuestionFeasibility.fixable;
    }
    return QuestionFeasibility.feasible;
  }

  String get feasibilityLabel {
    return switch (feasibility) {
      QuestionFeasibility.feasible => 'Fazível',
      QuestionFeasibility.fixable => 'Corrigível',
      QuestionFeasibility.notFeasible => 'Não fazível',
    };
  }

  String get feasibilityReason {
    return switch (feasibility) {
      QuestionFeasibility.feasible =>
        'Estrutura completa: enunciado, alternativas e gabarito reconhecidos.',
      QuestionFeasibility.fixable => _fixableReason(),
      QuestionFeasibility.notFeasible => _notFeasibleReason(),
    };
  }

  String _fixableReason() {
    final reasons = <String>[];
    if (warning != null) reasons.add(warning!);
    if (format != QuestionFormat.openEnded) {
      if (options.length < 2) reasons.add('Menos de 2 alternativas.');
      if (!hasVisualOptions && options.any((o) => o.trim().isEmpty)) {
        reasons.add('Alternativa(s) vazia(s).');
      }
      if (correctIndex == null ||
          correctIndex! < 0 ||
          correctIndex! >= options.length) {
        reasons.add('Gabarito não definido ou inválido.');
      }
    }
    if (format == QuestionFormat.openEnded && correctIndex != null) {
      reasons.add('Discursiva com gabarito objetivo inesperado.');
    }
    return reasons.isEmpty
        ? 'Requer ajuste manual antes de publicar.'
        : reasons.join(' ');
  }

  String _notFeasibleReason() {
    final reasons = <String>[];
    if (format == QuestionFormat.unknown) {
      reasons.add('Formato não reconhecido.');
    }
    if (statement.trim().length < 2) {
      reasons.add('Enunciado muito curto ou ausente.');
    }
    return reasons.isEmpty
        ? 'Não foi possível extrair estrutura utilizável.'
        : reasons.join(' ');
  }
}

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
  const QuestionParser({this.boardProfile});

  /// Perfil de banca detectado pelo `ExamLayoutProfiler`. Quando informado, o
  /// parser usa o layout reconhecido (alternativas de A a E, itens para julgar
  /// ou misto) como evidência estrutural para não descartar questões de bancas
  /// com formatos especiais, como as bancas militares (AFA, EPCAR, EEAR).
  ///
  /// Sem ground truth de cada banca, o perfil não inventa regras de detecção;
  /// ele apenas amplia a tolerância do parser universal ao formato declarado.
  final ExamLayoutProfile? boardProfile;

  List<ImportedQuestion> parse(String source) {
    final text = _normalize(source);
    if (text.trim().isEmpty) return const [];

    final lines = text.split('\n');
    final candidates = <_QuestionStart>[];
    final seenVariantsByNumber = <int, Set<String>>{};
    final candidateVariantLabels = <int, String>{};
    final candidateSectionIds = <int, int>{};
    final sourcePagesByLine = <int, int>{};
    var currentVariantLabel = 'Versão principal';
    var inInstructions = false;
    var previousNumber = -1;
    var currentSectionId = 0;
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
        if (_isNamedSectionHeading(_normalize(line))) {
          currentSectionId++;
          previousNumber = -1;
        }
        // Do not reset inInstructions here — the instruction block persists
        // until we actually find a real question with options (handled below).
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
      if (candidate == null ||
          (candidate.number == null && !candidate.explicit) ||
          (candidate.number != null && candidate.number! < 1) ||
          (!candidate.explicit && candidate.number! > 400)) {
        continue;
      }
      if (inInstructions) {
        // The numbered commands that open a caderno are not questions. Only a
        // marker the board itself wrote, or a numbered block with alternatives,
        // ends that block.
        if (!candidate.explicit && !hasFollowingOptions) continue;
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
        candidateSectionIds[i] = currentSectionId;
      }
      candidates.add(candidate.copyWith(lineIndex: i));
    }

    // A cover page is full of numbers — the booklet code, the colour of the
    // caderno, the day, the table of the answer sheet. When the board itself
    // writes “Questão 12”, that marker owns the number and every candidate the
    // scan inferred for it is noise from the pages around it.
    final explicitNumbers = <(int, String), Set<int>>{};
    for (final candidate in candidates) {
      final number = candidate.number;
      if (number == null || !candidate.explicit) continue;
      explicitNumbers
          .putIfAbsent((
            candidateSectionIds[candidate.lineIndex] ?? 0,
            candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal',
          ), () => <int>{})
          .add(number);
    }
    candidates.removeWhere((candidate) {
      final number = candidate.number;
      if (number == null || candidate.explicit) return false;
      final sectionAndVariant = (
        candidateSectionIds[candidate.lineIndex] ?? 0,
        candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal',
      );
      return explicitNumbers[sectionAndVariant]?.contains(number) == true;
    });

    final firstExplicitLineBySectionAndVariant = <(int, String), int>{};
    for (final candidate in candidates.where(
      (candidate) => candidate.explicit && candidate.number != null,
    )) {
      final sectionId = candidateSectionIds[candidate.lineIndex] ?? 0;
      final variantLabel =
          candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal';
      final sectionAndVariant = (sectionId, variantLabel);
      final current = firstExplicitLineBySectionAndVariant[sectionAndVariant];
      if (current == null || candidate.lineIndex < current) {
        firstExplicitLineBySectionAndVariant[sectionAndVariant] =
            candidate.lineIndex;
      }
    }
    candidates.removeWhere((candidate) {
      if (candidate.explicit) return false;
      final sectionAndVariant = (
        candidateSectionIds[candidate.lineIndex] ?? 0,
        candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal',
      );
      final firstExplicitLine =
          firstExplicitLineBySectionAndVariant[sectionAndVariant];
      return firstExplicitLine != null &&
          candidate.lineIndex < firstExplicitLine;
    });

    final firstQuestionSectionLine = lines.indexWhere(
      (line) => _isNamedSectionHeading(_normalize(line)),
    );
    if (firstQuestionSectionLine >= 0) {
      // A numbered block with alternatives is a question even when the first
      // named heading appears late in the caderno; only cover-page noise lacks
      // an option list. Bound the block by the next detected start rather than
      // a forward scan: a stray fraction, figure or table number inside the
      // stem must not hide the alternatives that follow it.
      final kept = <_QuestionStart>[];
      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        if (candidate.explicit ||
            candidate.lineIndex >= firstQuestionSectionLine) {
          kept.add(candidate);
          continue;
        }
        final blockEnd = i + 1 < candidates.length
            ? candidates[i + 1].lineIndex
            : lines.length;
        final scan = _findOptionMarkers(
          lines.sublist(candidate.lineIndex, blockEnd).join('\n'),
        );
        if (scan.markers.length >= 2 || scan.rawMarkerCount >= 2) {
          kept.add(candidate);
        }
      }
      candidates
        ..clear()
        ..addAll(kept);
    }

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

    return _restoreContiguousQuestionOrder(
      _coalesceParallelNumberedVersions(questions),
    );
  }

  List<ImportedQuestion> _restoreContiguousQuestionOrder(
    List<ImportedQuestion> questions,
  ) {
    if (questions.length < 2 ||
        questions.any((question) => question.number == null)) {
      return questions;
    }

    final numbers = questions
        .map((question) => question.number!)
        .toList(growable: false);
    final orderedNumbers = [...numbers]..sort();
    if (orderedNumbers.toSet().length != numbers.length ||
        orderedNumbers.last - orderedNumbers.first + 1 != numbers.length) {
      return questions;
    }

    return [...questions]
      ..sort((left, right) => left.number!.compareTo(right.number!));
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
    if (heading.length < 8) return false;
    if (_isNamedSectionHeading(_normalize(heading))) return true;
    return heading == heading.toUpperCase() &&
        RegExp(r'[A-ZÁÉÍÓÚÂÊÔÃÕÇ]{3}').hasMatch(heading);
  }

  bool _isNamedSectionHeading(String heading) => RegExp(
    r'^(?:conhecimentos gerais|conhecimentos espec[ií]ficos|'
    r'l[ií]ngua portuguesa|l[ií]ngua inglesa|l[ií]ngua espanhola|'
    r'quest[õo]es discursivas|quest[õo]es abertas|prova objetiva|'
    r'prova discursiva|parte [ivx]+)'
    r'(?:\s+(?:l[ií]ngua portuguesa|l[ií]ngua inglesa|l[ií]ngua espanhola|'
    r'conhecimentos gerais|conhecimentos espec[ií]ficos))?'
    r'(?:\s*\([^)]*\))?$',
    caseSensitive: false,
  ).hasMatch(heading);

  bool _isAnswerSheetNumber(List<String> lines, int lineIndex) =>
      lineIndex + 1 < lines.length &&
      RegExp(r'^\s*[-–—_.=]{8,}\s*$').hasMatch(lines[lineIndex + 1]);

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
    // The line right below a page number may be the next question's marker
    // (“3” then “10 - …”). The options after that marker belong to question 10,
    // not to the page number; believing otherwise invents a question 3 and
    // swallows question 10.
    if (_isNumberedMarkerLine(lines[start])) return false;
    final followingLines = <String>[];
    final end = (start + 80).clamp(0, lines.length);
    for (var index = start; index < end; index++) {
      if (index > start &&
          (RegExp(r'^\s*\d{1,3}\s*$').hasMatch(lines[index]) ||
              _isExplicitQuestionStartLine(lines[index]) ||
              // A passage prints its line numbers alone and a caderno writes
              // “01 - …” before the next item. Neither line can be evidence
              // that the options further down belong to the number above.
              _isNumberedMarkerLine(lines[index]))) {
        break;
      }
      if (_pageMarker.hasMatch(lines[index])) continue;
      followingLines.add(lines[index]);
      final scan = _findOptionMarkers(followingLines.join('\n'));
      if (scan.markers.length >= 2 || scan.rawMarkerCount >= 2) return true;
    }
    return false;
  }

  bool _isNumberedMarkerLine(String line) =>
      RegExp(r'^\s*\d{1,4}\s*[.)\-–—:]\s+\S').hasMatch(line.trim());

  /// A standalone number inside a text block whose previous line ends in the
  /// middle of a sentence and whose next line starts in lowercase is a printed
  /// line number, not a question marker.
  bool _looksLikePassageLineNumber(List<String> lines, int lineIndex) {
    final previous = _previousNonEmptyLine(lines, lineIndex - 1);
    final next = _nextNonEmptyLine(lines, lineIndex + 1);
    if (previous == null || next == null) return false;
    final previousText = previous.trim();
    final nextText = next.trim();
    if (previousText.isEmpty || nextText.isEmpty) return false;
    if (RegExp(r'[.!?;:)\]}"”’]$').hasMatch(previousText)) return false;
    if (!RegExp(r'^[a-zà-ÿ]').hasMatch(nextText)) return false;
    return !_isExplicitQuestionStartLine(nextText) &&
        !_isNumberedMarkerLine(nextText) &&
        _findOptionMarkers(nextText).rawMarkerCount == 0;
  }

  String? _previousNonEmptyLine(List<String> lines, int start) {
    for (var index = start; index >= 0; index--) {
      final value = lines[index].trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? _nextNonEmptyLine(List<String> lines, int start) {
    for (var index = start; index < lines.length; index++) {
      final value = lines[index].trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  bool _hasQuestionBodyAfter(List<String> lines, int lineIndex) {
    for (var index = lineIndex + 1; index < lines.length; index++) {
      final candidate = lines[index].trim();
      if (candidate.isEmpty) continue;
      if (_pageMarker.hasMatch(candidate)) continue;
      if (RegExp(r'^\d{1,3}$').hasMatch(candidate) ||
          _findOptionMarkers(candidate).rawMarkerCount > 0 ||
          _isExplicitQuestionStartLine(candidate)) {
        return false;
      }
      if (_isLikelyRunningHeader(candidate)) continue;
      return candidate.length >= 4;
    }
    return false;
  }

  bool _isExplicitQuestionStartLine(String line) => RegExp(
    r'^\s*(?:(?:quest(?:ão|ao)\s*|q(?:uestão|uestao)?\.?\s*)\d{1,4}\b'
    r'|\d{1,4}\s*[ªº°]\s*quest(?:ão|ao)\b)',
    caseSensitive: false,
  ).hasMatch(line.trim());

  bool _isLikelyRunningHeader(String line) =>
      line.length <= 80 &&
      line == line.toUpperCase() &&
      RegExp(r'[A-ZÁÉÍÓÚÂÊÔÃÕÇ]').hasMatch(line) &&
      !RegExp(r'[.!?;:]$').hasMatch(line);

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
    if (RegExp(
      r'^\s*\d{1,3}\s*[-–—]\s*quest(?:[õo]es|[ãa]o)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return _embeddedNumericQuestionStart(
        line,
        previousNumber,
        hasFollowingOptions: hasFollowingOptions,
      );
    }

    final discursiveHeading = RegExp(
      r'^\s*quest(?:ão|ao)\s+(?:discursiva|aberta)\s*[:.\-–—]?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    final discursiveContent = discursiveHeading?.group(1)?.trim() ?? '';
    if (discursiveHeading != null &&
        previousNumber > 0 &&
        (discursiveContent.length >= 4 ||
            _hasQuestionBodyAfter(lines, lineIndex))) {
      final isEssayPrompt = RegExp(
        r'\breda[cç][aã]o\b',
        caseSensitive: false,
      ).hasMatch(line);
      return _QuestionStart(
        lineIndex: -1,
        number: isEssayPrompt ? null : previousNumber + 1,
        content: discursiveContent,
        confidence: .78,
        explicit: isEssayPrompt,
      );
    }

    final reversedExplicit = RegExp(
      r'^\s*[ãa]o\s+(\d{1,4})\s+Quest\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (reversedExplicit != null) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(reversedExplicit.group(1)!),
        content: reversedExplicit.group(2)?.trim() ?? '',
        confidence: 1,
        explicit: true,
      );
    }
    final explicit = RegExp(
      r'^\s*(?:quest(?:ão|ao)\s*[˜~^´`’]?|q(?:uestão|uestao)?\.?)[ \t]*(?:n[º°.]?[ \t]*)?(\d{1,4})\s*(?:[.:)\-]+)?\s*(.*)$',
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

    final braced = RegExp(r'^\s*\{\s*(\d{1,4})\s*\}\s*(.*)$').firstMatch(line);
    if (braced != null) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(braced.group(1)!),
        content: braced.group(2)?.trim() ?? '',
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
    if (bareQuestionNumber != null && _isAnswerSheetNumber(lines, lineIndex)) {
      return null;
    }
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
    // A passage prints its own line numbers at the left margin. Without the
    // geometry they arrive as bare numbers between two halves of a sentence,
    // which looks like a sequential question marker. A real marker either
    // starts a sentence or precedes a question stem, not the middle of a word
    // from the line above.
    if (bareNumber != null && _looksLikePassageLineNumber(lines, lineIndex)) {
      return null;
    }
    if (bareNumber != null &&
        !isTableValue &&
        ((trueFalseContext &&
                hasQuestionBody &&
                (previousNumber < 0 ||
                    followsQuestionNumber ||
                    _inNumberingSlack(bareQuestionNumber, previousNumber))) ||
            (followsQuestionNumber &&
                (hasQuestionBody || hasFollowingOptions)) ||
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
    final embedded = _embeddedNumericQuestionStart(
      line,
      previousNumber,
      hasFollowingOptions: hasFollowingOptions,
    );
    if (embedded != null) return embedded;

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

  _QuestionStart? _embeddedNumericQuestionStart(
    String line,
    int previousNumber, {
    required bool hasFollowingOptions,
  }) {
    if (previousNumber < 0) return null;
    final candidates = RegExp(r'(?<!\d)(\d{1,3})\s+(?=["“‘A-ZÀ-Ú])')
        .allMatches(line);
    for (final match in candidates) {
      if (match.start == 0) continue;
      final number = int.tryParse(match.group(1)!);
      if (number != previousNumber + 1) continue;
      final prefix = line.substring(0, match.start).trimRight();
      final endsAtContextBoundary =
          prefix.endsWith(')') ||
          RegExp(
            r'P[aá]gina:\s*\d+\s+de\s+\d+\s*$',
            caseSensitive: false,
          ).hasMatch(prefix);
      if (!endsAtContextBoundary) continue;
      final content = line.substring(match.end).trim();
      if (content.length < 4 ||
          (!hasFollowingOptions &&
              _findOptionMarkers(content).markers.length < 2)) {
        continue;
      }
      return _QuestionStart(
        lineIndex: -1,
        number: number,
        content: content,
        confidence: .9,
        explicit: false,
      );
    }
    return null;
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
      final optionContent = _truncateAfterStimulusHeading(
        content,
        optionScan.markers,
      );
      final parsed = _parseOptions(optionContent, optionScan.markers);
      if (parsed == null) return _uncertainQuestion(content, start);
      final statement = _cleanStatement(parsed.statement);
      final missingOptionText = parsed.options.every(
        (option) => option.isEmpty,
      );
      final hasVisualOptions =
          parsed.options.length >= 4 &&
          parsed.options.any((option) => option.trim().isEmpty) &&
          _plausibleStatement(statement);
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
      if (hasVisualOptions) {
        warnings.add(
          'Alternativas identificadas, mas o conteúdo visual não foi extraído; revisar na página de origem.',
        );
      }
      return ImportedQuestion(
        statement: statement,
        options: parsed.options,
        number: start.number,
        format: QuestionFormat.multipleChoice,
        confidence: hasVisualOptions
            ? .65
            : stemIsMissing
            ? .6
            : _optionConfidence(
                start,
                parsed.options.length,
                hasIncoherentMarkers: optionScan.hasIncoherentMarkers,
              ),
        warning: warnings.isEmpty ? null : warnings.join(' '),
        hasVisualOptions: hasVisualOptions,
        fieldConfidence: {
          'statement': start.confidence,
          'options': parsed.options.isEmpty
              ? 0
              : parsed.options
                        .where((option) => option.trim().isNotEmpty)
                        .length /
                    parsed.options.length,
        },
      );
    }

    // ENEM prints the five answer letters once, over a row of image choices
    // whose text layer is empty: “ABCDE”. The letters are the only evidence
    // that the block has alternatives at all, so keep five explicit visual
    // slots instead of turning the item into an unknown-format question.
    final visualLabels = _visualOptionLabelCount(content);
    if (visualLabels >= 2) {
      return ImportedQuestion(
        statement: _cleanStatement(content.replaceAll(_visualOptionLine, '\n')),
        options: List<String>.filled(visualLabels, ''),
        number: start.number,
        format: QuestionFormat.multipleChoice,
        confidence: .65,
        hasVisualOptions: true,
        warning: 'Alternativas identificadas, mas o conteúdo visual não foi extraído; revisar na página de origem.',
        fieldConfidence: {'statement': start.confidence, 'options': 0},
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
        fieldConfidence: {'statement': .9, 'options': 1},
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
        fieldConfidence: {'statement': .72, 'options': 0},
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
        fieldConfidence: {'statement': .7, 'options': 0},
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
      fieldConfidence: {
        'statement': (start.confidence * .55).clamp(0, 1).toDouble(),
        'options': 0,
      },
    );
  }

  String _joinContent(String block, String firstLineContent) {
    final lines = block.split('\n');
    if (lines.isEmpty) return firstLineContent;
    lines[0] = firstLineContent;
    return lines.join('\n').trim();
  }

  String _truncateAfterStimulusHeading(
    String content,
    List<_OptionMarker> markers,
  ) {
    if (markers.isEmpty ||
        (markers.last.letter != 'D' && markers.last.letter != 'E')) {
      return content;
    }
    final stimulus = RegExp(
      r'^\s*(?:TEXTO(?:\s+DE\s+APOIO)?|QUADRO|FIGURA)\s+(?:[IVXLCDM]+|\d+)\s*$',
      caseSensitive: false,
      multiLine: true,
    );
    // A subject heading such as “QUÍMICA” opens the next section. Everything
    // after the last alternative belongs to that section, not to the option.
    final section = RegExp(
      r'^[ \t]*[A-ZÁÉÍÓÚÂÊÔÃÕÇ][A-ZÁÉÍÓÚÂÊÔÃÕÇ \t]{2,}[ \t]*$',
      multiLine: true,
    );
    final headings = [
      ...stimulus.allMatches(content),
      ...section.allMatches(content),
    ]..sort((left, right) => left.start.compareTo(right.start));
    for (final match in headings) {
      if (match.start > markers.last.contentStart) {
        return content.substring(0, match.start).trimRight();
      }
    }
    return content;
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
    final lineScanIsComplete =
        _isCompleteOptionSet(result) &&
        result.every((marker) => marker.text.isNotEmpty);
    if (result.length < 5 || !lineScanIsComplete) {
      final inline = _inlineMarkers(block);
      final inlineIsComplete = _isCompleteOptionSet(inline);
      // A complete inline A..N set is a structural signature: the text layer
      // returned the whole option grid on one line. It wins over line-scan
      // noise such as isolated chemical symbols, but never over a complete
      // filled line-by-line option set.
      if (inline.length > result.length ||
          (inlineIsComplete && inline.length >= 4 && !lineScanIsComplete)) {
        result
          ..clear()
          ..addAll(inline);
      }
    }

    var coherent = _coherentOptions(result);
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
  ///
  /// A list of alternatives always begins at A. Inline scans therefore keep
  /// only a consecutive run that starts there: abbreviations such as “P. M.”
  /// or “p. 49” are shaped like a label but never form A, B, C, D in order.
  List<_OptionMarker> _inlineMarkers(String block) {
    const circledUppercase = 'ⒶⒷⒸⒹⒺ';
    const circledLowercase = 'ⓐⓑⓒⓓⓔ';
    final circled = RegExp(r'[Ⓐ-Ⓔⓐ-ⓔ]').allMatches(block).toList();
    if (circled.length >= 2) {
      return circled.map((match) {
        final glyph = match.group(0)!;
        final index = circledUppercase.indexOf(glyph);
        final letterIndex = index >= 0
            ? index
            : circledLowercase.indexOf(glyph);
        return _OptionMarker(
          start: match.start,
          contentStart: match.end,
          letter: String.fromCharCode('A'.codeUnitAt(0) + letterIndex),
          text: '',
        );
      }).toList();
    }

    // ITA prints “A ( ) 14.”, sometimes in two rows or in three columns. The
    // empty box is the answer slot, not a right-and-wrong mark: the letter
    // before it makes the list of alternatives explicit.
    final boxed = RegExp(
      r'(?:^|\s)([A-Z])\s*\(\s*\)\s*',
      caseSensitive: false,
    ).allMatches(block).toList();
    if (boxed.length >= 2) {
      final markers = _inlineRun(boxed, block, minimumLength: 2);
      if (markers.isNotEmpty) return markers;
    }

    final punctuated = RegExp(
      r'(?:^|\s)(?:\(([A-Za-z])\)|\[([A-Za-z])\])\s+(?=\S)',
      caseSensitive: false,
    ).allMatches(block).toList();
    if (punctuated.length >= 2) {
      final markers = _inlineRun(punctuated, block, minimumLength: 2);
      if (markers.isNotEmpty) return markers;
    }

    final bare = RegExp(r'(?:^|\s)([A-E])\s+(?!\d)\S')
        .allMatches(block)
        .toList();
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

  /// Turns an inline scan into a list of alternatives only when the letters
  /// form a complete A, B, C, D… set (any layout order) or a consecutive run
  /// starting at A. Anything else is prose, an abbreviation or a citation.
  List<_OptionMarker> _inlineRun(
    List<RegExpMatch> matches,
    String block, {
    required int minimumLength,
  }) {
    final parsed = <({int code, RegExpMatch match})>[];
    for (final match in matches) {
      final raw = match.groupCount >= 3
          ? (match.group(1) ?? match.group(2) ?? match.group(3) ?? '')
          : match.groupCount >= 2
          ? (match.group(1) ?? match.group(2) ?? '')
          : (match.group(1) ?? '');
      if (raw.isEmpty) continue;
      parsed.add((code: raw.toUpperCase().codeUnitAt(0), match: match));
    }
    if (parsed.length < minimumLength) return const [];

    final codes = parsed.map((entry) => entry.code).toSet().toList()..sort();
    final completeSet =
        codes.length == parsed.length &&
        codes.first == 'A'.codeUnitAt(0) &&
        codes.last - codes.first + 1 == codes.length &&
        codes.length >= minimumLength;
    final selected = completeSet
        ? ([...parsed]..sort((a, b) => a.code.compareTo(b.code)))
        : _longestRunFromA(parsed);
    if (selected.length < minimumLength) return const [];
    return selected
        .map(
          (entry) => _OptionMarker(
            start: entry.match.start,
            contentStart: entry.match.end,
            letter: String.fromCharCode(entry.code),
            text: '',
          ),
        )
        .toList();
  }

  List<({int code, RegExpMatch match})> _longestRunFromA(
    List<({int code, RegExpMatch match})> parsed,
  ) {
    var best = <({int code, RegExpMatch match})>[];
    var run = <({int code, RegExpMatch match})>[];
    for (final entry in parsed) {
      if (run.isEmpty) {
        if (entry.code == 'A'.codeUnitAt(0)) run = [entry];
        continue;
      }
      if (entry.code == run.last.code + 1) {
        run.add(entry);
      } else {
        if (run.length > best.length) best = run;
        run = entry.code == 'A'.codeUnitAt(0) ? [entry] : [];
      }
    }
    if (run.length > best.length) best = run;
    return best;
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

  /// Exactly one marker per letter, starting at A with no gaps.
  bool _isCompleteOptionSet(List<_OptionMarker> markers) {
    if (markers.length < 2) return false;
    final letters =
        markers.map((marker) => marker.letter.codeUnitAt(0)).toSet().toList()
          ..sort();
    return letters.length == markers.length &&
        letters.first == 'A'.codeUnitAt(0) &&
        letters.last - letters.first + 1 == letters.length;
  }

  List<_OptionMarker> _coherentOptions(List<_OptionMarker> markers) {
    if (markers.length < 2) return const [];
    // A grid of alternatives can be printed in more than one column, so the
    // labels may appear as A, C, E, B, D. When the scan found exactly one of
    // each label from A onward, the letters themselves give the order.
    final uniqueLetters =
        markers.map((marker) => marker.letter.codeUnitAt(0)).toSet().toList()
          ..sort();
    final isCompleteSet =
        uniqueLetters.length == markers.length &&
        uniqueLetters.first == 'A'.codeUnitAt(0) &&
        uniqueLetters.last - uniqueLetters.first + 1 == uniqueLetters.length;
    if (isCompleteSet) {
      return [...markers]..sort((a, b) => a.letter.compareTo(b.letter));
    }

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

    // A list of alternatives starts at A. A marker found before it is a
    // citation or an abbreviation, never the first choice.
    final firstA = markers.indexWhere((marker) => marker.letter == 'A');
    if (firstA < 0) {
      // A two-column text layer can drop the first alternatives and leave only
      // a consecutive tail such as C, D, E. Preserve those visible alternatives
      // instead of discarding the whole list; the gate still flags the
      // incomplete question for review.
      var best = <_OptionMarker>[];
      var run = <_OptionMarker>[];
      for (final marker in markers) {
        final continues =
            marker.text.isNotEmpty &&
            run.isNotEmpty &&
            marker.letter.codeUnitAt(0) == run.last.letter.codeUnitAt(0) + 1;
        if (marker.text.isEmpty || (run.isNotEmpty && !continues)) {
          if (run.length > best.length) best = run;
          run = <_OptionMarker>[];
        }
        if (marker.text.isNotEmpty) run.add(marker);
      }
      if (run.length > best.length) best = run;
      return best.length >= 2 ? best : const [];
    }
    final output = <_OptionMarker>[markers[firstA]];
    var previous = 'A'.codeUnitAt(0);
    for (var i = firstA + 1; i < markers.length; i++) {
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
    final byPosition = [...markers]
      ..sort((left, right) => left.start.compareTo(right.start));
    final textByMarker = <_OptionMarker, String>{};
    for (var i = 0; i < byPosition.length; i++) {
      final marker = byPosition[i];
      final end = i + 1 < byPosition.length
          ? byPosition[i + 1].start
          : block.length;
      var text = block.substring(marker.contentStart, end).trim();
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      // AOCP and Instituto MAIS write “A - alternativa”. The dash is the label's
      // punctuation, not part of the answer, while “-19.” keeps its sign.
      text = text.replaceFirst(RegExp(r'^[-–—]\s+'), '').trim();
      // Remove page separators like "#####" that leak from PDF text layer.
      text = text.replaceAll(RegExp(r'\s*#{3,}\s*'), ' ').trim();
      // Strip known footer/header watermarks (ENEM, year, board name) that leak
      // into option text from page edges. Only strip from START/END to avoid
      // removing legitimate content (e.g. "2022" inside a date).
      text = _stripFooterWatermarks(text);
      textByMarker[marker] = text;
    }
    final options = [for (final marker in markers) textByMarker[marker]!];
    if (options.length < 2) return null;

    final statementEnd = byPosition.first.start;
    final statement = block.substring(0, statementEnd).trim();
    return _ParsedOptions(statement: statement, options: options);
  }

  /// Strips known footer/header watermarks (ENEM, year, board name) from a
  /// string. Removes from START, END, and also standalone occurrences in the
  /// MIDDLE that look like footer insertions (e.g. "2022 QUESTÃO", "ENEM" between words).
  String _stripFooterWatermarks(String text) {
    const patterns = [
      r'ENEM\s*\d{4}',
      r'ENEM',
      r'INEP',
      r'ENCCEJA',
      r'\b202[2-5]\b',
      // Note: bare numbers (^\d{1,2}$) are NOT stripped here because they can
      // be legitimate option content (e.g. "4" in "B) 4"). Page numbers are
      // handled by the furniture filter at page edges.
    ];
    var result = text;
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      // Strip from start
      result = result.replaceFirst(regex, '').trim();
      // Strip from end
      result = result
          .replaceFirst(RegExp('$pattern\$', caseSensitive: false), '')
          .trim();
      // Strip standalone occurrences in middle (surrounded by spaces or boundaries)
      // e.g. "texto 2022 QUESTÃO" -> "texto QUESTÃO"
      result = result
          .replaceAll(
            RegExp(r'(?<=\s)' + pattern + r'(?=\s)', caseSensitive: false),
            '',
          )
          .trim();
      // Also handle "pattern TEXT" at start of segment (e.g. "2022 QUESTÃO 03")
      result = result
          .replaceFirst(
            RegExp('^' + pattern + r'\s+', caseSensitive: false),
            '',
          )
          .trim();
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  /// A standalone row of answer letters, such as the “ABCDE” ENEM prints over
  /// alternatives that exist only as images.
  static final RegExp _visualOptionLine = RegExp(
    r'^\s*(A(?:\s*[B-E]){1,4})\s*$',
    caseSensitive: false,
    multiLine: true,
  );

  int _visualOptionLabelCount(String content) {
    for (final match in _visualOptionLine.allMatches(content)) {
      final letters = match
          .group(1)!
          .replaceAll(RegExp(r'\s+'), '')
          .toUpperCase();
      if (letters.length >= 2) return letters.length;
    }
    return 0;
  }

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
    // ITA writes “A ( ) …” instead of “A) …”. The letter before the box is
    // still an alternative label, so the empty parens are not a C/E pair.
    final boxed = RegExp(
      r'(?:^|\s)([A-F])\s*\(\s*\)',
      caseSensitive: false,
    ).allMatches(content);
    letters.addAll(boxed.map((match) => match.group(1)!.toUpperCase()));
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

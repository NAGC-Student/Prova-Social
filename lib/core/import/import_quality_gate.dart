import 'pdf_text_extractor.dart';
import 'import_diagnostic_event.dart';
import 'question_parser.dart';
import 'text_normalizer.dart';

enum ImportQualityStatus { good, review, retry }

class ImportQualityAssessment {
  const ImportQualityAssessment({
    required this.status,
    required this.parserConfidence,
    required this.ocrConfidence,
    required this.questionsNeedingReview,
    required this.questionsWithVariants,
    required this.duplicateQuestionCount,
    required this.incompleteQuestionCount,
    required this.expectedQuestionCount,
    required this.questionCountMismatch,
    required this.missingExpectedQuestionCount,
    required this.unreadablePages,
    required this.numberingIssues,
    required this.diagnostics,
    required this.reasons,
  });

  final ImportQualityStatus status;
  final double? parserConfidence;
  final double? ocrConfidence;
  final int questionsNeedingReview;
  final int questionsWithVariants;
  final int duplicateQuestionCount;
  final int incompleteQuestionCount;
  final int? expectedQuestionCount;
  final bool questionCountMismatch;
  final int missingExpectedQuestionCount;
  final int unreadablePages;
  final int numberingIssues;
  final List<ImportDiagnosticEvent> diagnostics;
  final List<String> reasons;
}

/// Decides whether the extraction can be reviewed, needs a retry, or has no
/// structural warning. Questions below the auto-validation threshold remain
/// explicitly reviewable in the import editor.
class ImportQualityGate {
  const ImportQualityGate({
    this.reviewConfidenceThreshold = autoValidatedQuestionConfidence,
  });

  final double reviewConfidenceThreshold;

  void markNumberingIssues(List<ImportedQuestion> questions) {
    final flagged = <int>{};
    int? previousNumber;
    int? previousIndex;
    for (var index = 0; index < questions.length; index++) {
      final number = questions[index].number;
      if (number == null) continue;
      if ((previousNumber == null && number != 1) ||
          (previousNumber != null && number != previousNumber + 1) ||
          number <= 0) {
        flagged.add(index);
        if (previousNumber != null && number <= previousNumber) {
          flagged.add(previousIndex!);
        }
      }
      previousNumber = number;
      previousIndex = index;
    }
    for (final index in flagged) {
      final question = questions[index];
      const warning =
          'Numeração fora de sequência; confira se há questão ausente, duplicada ou fora de ordem.';
      if (question.warning == null) {
        question.warning = warning;
      } else if (!question.warning!.contains(warning)) {
        question.warning = '${question.warning} $warning';
      }
      question.reviewState = QuestionReviewState.needsAttention;
    }
  }

  ImportQualityAssessment assess(
    PdfExtractionResult extraction,
    List<ImportedQuestion> questions, {
    int? expectedQuestionCount,
  }) {
    if (expectedQuestionCount != null && expectedQuestionCount < 1) {
      throw ArgumentError.value(
        expectedQuestionCount,
        'expectedQuestionCount',
        'Must be positive when provided.',
      );
    }
    final duplicateQuestionCount = _markDuplicateQuestions(questions);
    final incompleteQuestionCount = _markIncompleteQuestions(questions);
    final questionCountMismatch =
        expectedQuestionCount != null &&
        expectedQuestionCount != questions.length;
    final missingExpectedQuestionCount = expectedQuestionCount == null
        ? 0
        : expectedQuestionCount > questions.length
        ? expectedQuestionCount - questions.length
        : 0;
    final unreadablePages = extraction.unreadablePages;
    final confidenceThreshold = reviewConfidenceThreshold.isFinite
        ? reviewConfidenceThreshold.clamp(0, 1).toDouble()
        : autoValidatedQuestionConfidence;
    final ocrScores = extraction.pages
        .where((page) => page.source == PdfPageTextSource.onDeviceOcr)
        .map((page) => page.confidence)
        .whereType<double>()
        .where((score) => score.isFinite)
        .map((score) => score.clamp(0, 1).toDouble())
        .toList(growable: false);
    final questionScores = questions
        .map((question) => question.confidence)
        .where((score) => score.isFinite)
        .map((score) => score.clamp(0, 1).toDouble())
        .toList(growable: false);
    final parserConfidence = questionScores.isEmpty
        ? null
        : questionScores.reduce((a, b) => a + b) / questionScores.length;
    final ocrConfidence = ocrScores.isEmpty
        ? null
        : ocrScores.reduce((a, b) => a + b) / ocrScores.length;
    final questionsNeedingReview = questions
        .where(
          (question) =>
              !question.confidence.isFinite ||
              question.confidence < confidenceThreshold ||
              question.warning != null,
        )
        .length;
    final questionsWithVariants = questions
        .where((question) => question.alternateVersions.isNotEmpty)
        .length;
    final numberingIssues = _countNumberingIssues(questions);
    final reasons = <String>[];
    if (extraction.pageCount == 0) {
      reasons.add('Nenhuma página foi extraída do arquivo.');
    }
    if (unreadablePages > 0) {
      reasons.add('$unreadablePages página(s) sem texto suficiente.');
    }
    if (extraction.pagesWithWarnings > 0) {
      reasons.add(
        '${extraction.pagesWithWarnings} página(s) com aviso de OCR.',
      );
    }
    if (questionsNeedingReview > 0) {
      reasons.add(
        '$questionsNeedingReview '
        '${questionsNeedingReview == 1 ? 'questão precisa' : 'questões precisam'} '
        'de revisão por estrutura incerta.',
      );
    }
    if (duplicateQuestionCount > 0) {
      reasons.add(
        '$duplicateQuestionCount '
        '${duplicateQuestionCount == 1 ? 'questão duplicada' : 'questões duplicadas'} '
        'no texto extraído; confira antes de usar.',
      );
    }
    if (incompleteQuestionCount > 0) {
      reasons.add(
        '$incompleteQuestionCount '
        '${incompleteQuestionCount == 1 ? 'questão está' : 'questões estão'} '
        'com estrutura incompleta; confira enunciado, alternativas e gabarito.',
      );
    }
    if (questionCountMismatch) {
      reasons.add(
        'Você informou $expectedQuestionCount questões, mas o sistema '
        'identificou ${questions.length}. Confira possíveis perdas ou '
        'questões excedentes.',
      );
    }
    if (numberingIssues > 0) {
      reasons.add(
        'Sequência numérica inconsistente em $numberingIssues ponto(s); '
        'verificar questões ausentes, duplicadas ou fora de ordem.',
      );
    }

    final status =
        extraction.pageCount == 0 ||
            questions.isEmpty ||
            (extraction.pageCount > 0 &&
                unreadablePages == extraction.pageCount)
        ? ImportQualityStatus.retry
        : reasons.isNotEmpty
        ? ImportQualityStatus.review
        : ImportQualityStatus.good;
    final diagnostics = ImportDiagnosticEvent.collect(
      extraction: extraction,
      questions: questions,
      numberingIssues: numberingIssues,
      questionsNeedingReview: questionsNeedingReview,
      parserConfidence: parserConfidence,
      duplicateQuestionCount: duplicateQuestionCount,
      incompleteQuestionCount: incompleteQuestionCount,
      questionCountMismatch: questionCountMismatch,
    );
    return ImportQualityAssessment(
      status: status,
      parserConfidence: parserConfidence,
      ocrConfidence: ocrConfidence,
      questionsNeedingReview: questionsNeedingReview,
      questionsWithVariants: questionsWithVariants,
      duplicateQuestionCount: duplicateQuestionCount,
      incompleteQuestionCount: incompleteQuestionCount,
      expectedQuestionCount: expectedQuestionCount,
      questionCountMismatch: questionCountMismatch,
      missingExpectedQuestionCount: missingExpectedQuestionCount,
      unreadablePages: unreadablePages,
      numberingIssues: numberingIssues,
      diagnostics: diagnostics,
      reasons: List.unmodifiable(reasons),
    );
  }

  int _countNumberingIssues(List<ImportedQuestion> questions) {
    var issues = 0;
    int? previousNumber;
    for (final question in questions) {
      final number = question.number;
      if (number == null) continue;
      if (number <= 0) {
        issues++;
        previousNumber = number;
        continue;
      }
      if (previousNumber == null && number != 1) {
        issues++;
      } else if (previousNumber != null && number != previousNumber + 1) {
        issues++;
      }
      previousNumber = number;
    }
    return issues;
  }

  int _markDuplicateQuestions(List<ImportedQuestion> questions) {
    final indicesByContent = <String, List<int>>{};
    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      final statement = _normalizeForComparison(question.statement);
      if (statement.isEmpty) continue;
      final options = question.options
          .map(_normalizeForComparison)
          .toList(growable: false);
      final fingerprint = [
        question.format.name,
        statement,
        ...options,
      ].join('\u0000');
      indicesByContent.putIfAbsent(fingerprint, () => []).add(index);
    }

    var duplicates = 0;
    for (final indices in indicesByContent.values.where(
      (indices) => indices.length > 1,
    )) {
      duplicates += indices.length - 1;
      for (final index in indices) {
        _flagForReview(
          questions[index],
          'Conteúdo duplicado no texto extraído; confirme se a questão aparece mais de uma vez na prova.',
        );
      }
    }
    return duplicates;
  }

  int _markIncompleteQuestions(List<ImportedQuestion> questions) {
    var incomplete = 0;
    for (final question in questions) {
      final hasInvalidAnswer =
          question.correctIndex != null &&
          (question.correctIndex! < 0 ||
              question.correctIndex! >= question.options.length);
      final hasInvalidStatement = question.statement.trim().length < 2;
      final requiresOptions = switch (question.format) {
        QuestionFormat.multipleChoice ||
        QuestionFormat.trueFalse ||
        QuestionFormat.assertion => true,
        QuestionFormat.openEnded || QuestionFormat.unknown => false,
      };
      final hasInvalidOptions =
          requiresOptions &&
          (question.options.length < 2 ||
              question.options.any((option) => option.trim().isEmpty));
      final hasUnknownFormat = question.format == QuestionFormat.unknown;
      if (!hasInvalidAnswer &&
          !hasInvalidStatement &&
          !hasInvalidOptions &&
          !hasUnknownFormat) {
        continue;
      }
      incomplete++;
      _flagForReview(
        question,
        'Estrutura incompleta ou formato não identificado; confira enunciado, alternativas e gabarito.',
      );
    }
    return incomplete;
  }

  String _normalizeForComparison(String value) =>
      ExamTextNormalizer.normalize(value)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  void _flagForReview(ImportedQuestion question, String warning) {
    if (!question.warnings.contains(warning)) question.warnings.add(warning);
    if (question.warning == null) {
      question.warning = warning;
    } else if (!question.warning!.contains(warning)) {
      question.warning = '${question.warning} $warning';
    }
    question.reviewState = QuestionReviewState.needsAttention;
  }
}

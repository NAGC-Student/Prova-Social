import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/import_diagnostic_event.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/ocr_router.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

PdfExtractionResult extraction({
  PdfPageTextSource source = PdfPageTextSource.nativeText,
  String text = 'A native page containing enough text to import.',
  double? confidence,
  String? warning,
}) => PdfExtractionResult(
  ocrAvailable: true,
  pages: [
    PdfPageExtraction(
      pageNumber: 1,
      nativeText: source == PdfPageTextSource.nativeText ? text : '',
      text: text,
      source: source,
      ocrAttempted: source == PdfPageTextSource.onDeviceOcr,
      route: source == PdfPageTextSource.nativeText
          ? OcrRoute.nativeText
          : source == PdfPageTextSource.onDeviceOcr
          ? OcrRoute.paddleOcr
          : OcrRoute.unavailable,
      routeReason: 'test',
      confidence: confidence,
      warning: warning,
    ),
  ],
);

ImportedQuestion question({
  double confidence = .99,
  String? warning,
  int? number,
  String? statement,
}) => ImportedQuestion(
  statement:
      statement ??
      (number == null
          ? 'A question with enough text?'
          : 'A question with enough text, number $number?'),
  options: const ['First option', 'Second option'],
  confidence: confidence,
  warning: warning,
  number: number,
);

void main() {
  const gate = ImportQualityGate();

  test('auto-validates clear extraction at 99% confidence', () {
    final result = gate.assess(extraction(), [question()]);
    expect(result.status, ImportQualityStatus.good);
    expect(result.parserConfidence, .99);
    expect(result.questionsNeedingReview, 0);
    expect(result.numberingIssues, 0);
    expect(result.diagnostics, isEmpty);
  });

  test('requires human review below 99% confidence', () {
    final result = gate.assess(extraction(), [question(confidence: .80)]);
    expect(result.questionsNeedingReview, 1);
    expect(question(confidence: .99).reviewState, QuestionReviewState.reviewed);
    expect(
      question(confidence: .80).reviewState,
      QuestionReviewState.unreviewed,
    );
    expect(
      question(confidence: .79).reviewState,
      QuestionReviewState.needsAttention,
    );
  });

  test('routes gaps and out-of-order numbering to human review', () {
    final questions = [
      question(number: 1),
      question(number: 3),
      question(number: 2),
    ];
    gate.markNumberingIssues(questions);
    final result = gate.assess(extraction(), questions);

    expect(result.status, ImportQualityStatus.review);
    expect(result.numberingIssues, 2);
    expect(result.questionsNeedingReview, 2);
    expect(
      result.reasons,
      contains(
        'Sequência numérica inconsistente em 2 ponto(s); verificar questões ausentes, duplicadas ou fora de ordem.',
      ),
    );
    expect(
      result.diagnostics.map((event) => event.failure),
      contains(ImportFailureCode.inconsistentNumbering),
    );
  });

  test('detects duplicate question content and requires human review', () {
    final duplicate = [
      question(),
      ImportedQuestion(
        statement: 'A question\nwith enough text?',
        options: const ['First option', 'Second option'],
        confidence: .99,
      ),
    ];

    final result = gate.assess(extraction(), duplicate);

    expect(result.status, ImportQualityStatus.review);
    expect(result.duplicateQuestionCount, 1);
    expect(result.questionsNeedingReview, 2);
    expect(
      duplicate.every(
        (item) => item.reviewState == QuestionReviewState.needsAttention,
      ),
      isTrue,
    );
    expect(
      result.diagnostics.map((event) => event.failure),
      contains(ImportFailureCode.duplicateQuestion),
    );
    expect(
      result.reasons,
      contains('1 questão duplicada no texto extraído; confira antes de usar.'),
    );
  });

  test(
    'flags malformed objective questions but allows open-ended questions',
    () {
      final questions = [
        ImportedQuestion(
          statement: 'Questão sem opções suficientes?',
          options: const ['Única alternativa'],
          correctIndex: 2,
          confidence: .99,
        ),
        ImportedQuestion(
          statement: 'Explique o raciocínio utilizado.',
          options: const [],
          format: QuestionFormat.openEnded,
          confidence: .99,
        ),
      ];

      final result = gate.assess(extraction(), questions);

      expect(result.status, ImportQualityStatus.review);
      expect(result.incompleteQuestionCount, 1);
      expect(result.questionsNeedingReview, 1);
      expect(questions.first.reviewState, QuestionReviewState.needsAttention);
      expect(questions.last.warning, isNull);
      expect(
        result.diagnostics.map((event) => event.failure),
        contains(ImportFailureCode.incompleteQuestionStructure),
      );
    },
  );

  test('compares extraction with a user-confirmed expected count', () {
    final result = gate.assess(extraction(), [
      question(),
    ], expectedQuestionCount: 3);

    expect(result.status, ImportQualityStatus.review);
    expect(result.expectedQuestionCount, 3);
    expect(result.questionCountMismatch, isTrue);
    expect(result.missingExpectedQuestionCount, 2);
    expect(
      result.reasons,
      contains(
        'Você informou 3 questões, mas o sistema identificou 1. Confira possíveis perdas ou questões excedentes.',
      ),
    );
    expect(
      result.diagnostics.map((event) => event.failure),
      contains(ImportFailureCode.questionCountMismatch),
    );
  });

  test(
    'reports extra questions without claiming that questions are missing',
    () {
      final result = gate.assess(extraction(), [
        question(number: 1),
        question(number: 2),
      ], expectedQuestionCount: 1);

      expect(result.questionCountMismatch, isTrue);
      expect(result.missingExpectedQuestionCount, 0);
      expect(result.status, ImportQualityStatus.review);
    },
  );

  test(
    'creates a content-free diagnostic fingerprint for unknown structure',
    () {
      const privateText = '''
Material reservado para revisão interna.
Este texto confidencial não deve ser enviado.
Outra linha de conteúdo privado para diagnóstico.
''';
      const differentTextWithSameShape = '''
Documento protegido para avaliação manual.
Este conteúdo restrito permanece no dispositivo.
Mais uma linha particular para o diagnóstico.
''';

      ImportQualityAssessment assess(String text) =>
          gate.assess(extraction(text: text), const []);

      final first = assess(privateText).diagnostics.single;
      final second = assess(differentTextWithSameShape).diagnostics.single;
      final payload = first.toJson();

      expect(first.failure, ImportFailureCode.unknownStructure);
      expect(first.sourceType, 'private');
      expect(first.pattern, 'UNKNOWN_STRUCTURE_V1');
      expect(first.patternFingerprint, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(first.patternFingerprint, second.patternFingerprint);
      expect(first.needsReview, isTrue);
      expect(payload, isNot(contains(privateText)));
      expect(payload.values, isNot(contains(privateText)));
      expect(payload.values, isNot(contains('reservado')));
      expect(payload.values, isNot(contains('confidencial')));
    },
  );

  test('routes low-confidence questions and OCR warnings to review', () {
    final result = gate.assess(
      extraction(
        source: PdfPageTextSource.onDeviceOcr,
        confidence: .61,
        warning: 'OCR incerto.',
      ),
      [question(confidence: .72, warning: 'Alternativas incertas.')],
    );
    expect(result.status, ImportQualityStatus.review);
    expect(result.ocrConfidence, .61);
    expect(result.questionsNeedingReview, 1);
    expect(result.reasons, hasLength(2));
  });

  test('requests retry when the parser finds no questions', () {
    final result = gate.assess(extraction(), const []);
    expect(result.status, ImportQualityStatus.retry);
    expect(result.parserConfidence, isNull);
  });

  test('requests retry when there are questions but no extracted pages', () {
    const emptyExtraction = PdfExtractionResult(pages: [], ocrAvailable: false);

    final result = gate.assess(emptyExtraction, [question()]);

    expect(result.status, ImportQualityStatus.retry);
    expect(result.reasons, contains('Nenhuma página foi extraída do arquivo.'));
  });

  test(
    'routes invalid parser confidence to review without poisoning average',
    () {
      final result = gate.assess(extraction(), [
        question(confidence: double.nan),
        question(
          confidence: .99,
          statement: 'A different question with enough text?',
        ),
      ]);

      expect(result.status, ImportQualityStatus.review);
      expect(result.parserConfidence, .99);
      expect(result.questionsNeedingReview, 1);
    },
  );
}

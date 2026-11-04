import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test(
    'imports all 80 original synthetic questions from a two-column PDF',
    () async {
      final corpus = jsonDecode(
        await File('test/fixtures/import_corpus.json').readAsString(),
      ) as Map<String, dynamic>;
      expect(corpus['schemaVersion'], 1);
      final benchmark = (corpus['benchmarks'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((item) => item['id'] == 'synthetic-two-column-80');
      final source = benchmark['source'] as Map<String, dynamic>;
      expect(source['kind'], 'synthetic');
      expect(source['allowedForTesting'], isTrue);
      expect(source['allowedForProductContent'], isFalse);
      final document = benchmark['document'] as Map<String, dynamic>;
      final parserSnapshot =
          benchmark['parserSnapshot'] as Map<String, dynamic>;
      final pdf = await File(document['path'] as String).readAsBytes();
      expect(sha256.convert(pdf).toString(), document['sha256']);
      final parserSource = await File(parserSnapshot['path'] as String)
          .readAsBytes();
      expect(
        sha256.convert(parserSource).toString(),
        parserSnapshot['sha256'],
        reason: 'Update the parser snapshot after intentional review.',
      );
      final extraction = await const PdfTextExtractor().extract(
        pdf,
        sourceName: document['path'] as String,
      );
      final questions = const QuestionParser().parsePages(
        extraction.pages.map((page) => page.text).toList(growable: false),
      );
      final quality = const ImportQualityGate().assess(extraction, questions);

      expect(extraction.pageCount, parserSnapshot['expectedPages']);
      expect(
        extraction.unreadablePages,
        parserSnapshot['expectedUnreadablePages'],
      );
      expect(questions, hasLength(parserSnapshot['expectedQuestions'] as int));
      expect(questions.map((question) => question.number), [
        for (var number = 1; number <= 80; number++) number,
      ]);
      expect(
        questions.every((question) => question.sourcePage != null),
        isTrue,
      );
      expect(
        questions.map((question) => question.sourcePage).toSet(),
        containsAll(List.generate(8, (index) => index + 1)),
      );
      expect(
        questions.every((question) => question.options.length == 5),
        isTrue,
      );
      expect(
        questions.every((question) => question.statement.contains('n =')),
        isTrue,
      );
      expect(questions.map((question) => question.options[2]), [
        for (var number = 1; number <= 80; number++)
          'Código ${(3 * number + 2).toString().padLeft(3, '0')}',
      ]);
      expect(quality.status, ImportQualityStatus.good);
      expect(
        quality.questionsNeedingReview,
        parserSnapshot['expectedQuestionsNeedingReview'],
      );
    },
  );

  test('rejects PDFs above the configured page limit', () async {
    final pdf = await File(
      'test/fixtures/synthetic_two_column_80_questions.pdf',
    ).readAsBytes();

    await expectLater(
      const PdfTextExtractor().extract(pdf, maxPages: 7),
      throwsA(
        isA<PdfPageLimitException>()
            .having((error) => error.pageCount, 'pageCount', 8)
            .having((error) => error.limit, 'limit', 7),
      ),
    );
  });
}

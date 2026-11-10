import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:prova_social/core/import/imported_document.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('imports the user-provided 2024 VUNESP exam structurally', () async {
    final corpus = jsonDecode(
      await File('test/fixtures/import_corpus.json').readAsString(),
    ) as Map<String, dynamic>;
    final benchmark = (corpus['benchmarks'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['id'] == 'user-provided-vunesp-2024-pm-sp');
    final source = benchmark['source'] as Map<String, dynamic>;
    expect(source['kind'], 'user-provided-benchmark');
    expect(source['licenseStatus'], 'not-verified');
    expect(source['allowedForTesting'], isTrue);
    expect(source['allowedForProductContent'], isFalse);
    final document = benchmark['document'] as Map<String, dynamic>;
    final parserSnapshot = benchmark['parserSnapshot'] as Map<String, dynamic>;
    final bytes = await File(document['path'] as String).readAsBytes();
    expect(sha256.convert(bytes).toString(), document['sha256']);
    expect(
      sha256
          .convert(await File(parserSnapshot['path'] as String).readAsBytes())
          .toString(),
      parserSnapshot['sha256'],
      reason: 'Update the parser snapshot after intentional review.',
    );
    final extraction = await const PdfTextExtractor().extract(
      bytes,
      sourceName: document['path'] as String,
    );
    final questions = const QuestionParser().parsePages(
      extraction.pages.map((page) => page.text).toList(growable: false),
    );
    const qualityGate = ImportQualityGate();
    qualityGate.markNumberingIssues(questions);
    final quality = qualityGate.assess(extraction, questions);

    expect(extraction.pageCount, parserSnapshot['expectedPages']);
    expect(extraction.pagesWithText, parserSnapshot['expectedPages']);
    expect(extraction.ocrPages, 0);
    expect(
      extraction.unreadablePages,
      parserSnapshot['expectedUnreadablePages'],
    );
    expect(questions, hasLength(parserSnapshot['expectedQuestions'] as int));
    expect(questions.every((question) => question.sourcePage != null), isTrue);
    expect(questions.map((question) => question.number), [
      for (var number = 1; number <= 80; number++) number,
    ]);

    final byNumber = {
      for (final question in questions) question.number: question,
    };
    expect(byNumber[49]!.options, ['-19.', '-7.', '1.', '8.', '20.']);
    expect(byNumber[52]!.statement, contains('Considere as funções'));
    expect(byNumber[53]!.statement, contains('triângulo retângulo'));
    expect(byNumber[53]!.statement, contains('O valor de sen'));
    expect(byNumber[53]!.options, ['', '', '', '', '']);
    expect(byNumber[49]!.warning, isNull);
    expect([
      for (var number = 39; number <= 44; number++)
        byNumber[number]!.alternateVersions.single.label,
    ], everyElement('Espanhol'));
    expect(byNumber[39]!.versionLabel, 'Inglês');

    for (final number in [53, 54, 79, 80]) {
      expect(byNumber[number]!.options, ['', '', '', '', '']);
      expect(byNumber[number]!.hasVisualOptions, isTrue);
      expect(
        byNumber[number]!.warning,
        contains('conteúdo visual não foi extraído'),
      );
    }
    expect(quality.incompleteQuestionCount, 0);
    final questionVisualSources = associateQuestionVisualSources(questions);
    expect(questionVisualSources, hasLength(4));
    for (final number in [53, 54, 79, 80]) {
      final question = byNumber[number]!;
      final media = questionVisualSources.singleWhere(
        (item) => item.questionId == question.id,
      );
      expect(question.supportingMaterialIds, contains(media.id));
      expect(media.raw['sourcePages'], question.sourcePages);
      expect(media.id, startsWith('question-visual-${question.id}'));
    }
    expect(byNumber[80]!.statement, isNot(contains('Texto 1')));
    expect(byNumber[80]!.statement, contains('No Google Drive'));
    expect(byNumber[80]!.statement, contains('Para copiar os links'));
    expect(byNumber[80]!.statement, isNot(contains('disposição das formas')));
    expect(byNumber[80]!.options, everyElement(isEmpty));
    expect(byNumber[80]!.statement, isNot(contains('RASCUNHO')));
    expect(byNumber[80]!.statement, isNot(contains('CLASSIFICAÇÃO PERIÓDICA')));
    expect(byNumber[53]!.sourcePages, [19]);
    expect(byNumber[54]!.sourcePages, [20]);
    expect(byNumber[79]!.sourcePages, [28, 29]);
    expect(byNumber[80]!.sourcePages, [29]);
    expect(extraction.pages[29].text, contains('REDAÇÃO'));
    expect(extraction.pages[30].text, contains('RASCUNHO'));
    expect(extraction.pages[31].text, contains('CLASSIFICAÇÃO'));
    expect(extraction.pages[31].text, contains('ÓDICA'));
    expect(quality.status, ImportQualityStatus.review);
    expect(
      quality.questionsNeedingReview,
      parserSnapshot['expectedQuestionsNeedingReview'],
    );

    final questionPages = byNumber.values
        .where((question) => question.warning != null)
        .expand((question) => question.sourcePages)
        .toSet();
    final referencePages = extraction.pages
        .where((page) {
          final text = page.text.toUpperCase();
          return text.contains('CLASSIFICAÇÃO') &&
              !text.contains('NO FINAL DESTE CADERNO');
        })
        .map((page) => page.pageNumber)
        .toSet();
    if (extraction.pages.any(
      (page) =>
          page.text.toUpperCase().contains('NO FINAL DESTE CADERNO') &&
          page.text.toUpperCase().contains('CLASSIFICAÇÃO'),
    )) {
      referencePages.add(extraction.pageCount);
    }
    final previews = await const PdfTextExtractor().renderPages(bytes, {
      ...questionPages,
      ...referencePages,
    });
    expect(questionPages, {19, 20, 28, 29});
    expect(referencePages, {32});
    expect(previews.keys.toSet(), {19, 20, 28, 29, 32});
    final totalPreviewBytes = previews.values.fold<int>(
      0,
      (sum, bytes) => sum + bytes.length,
    );
    expect(totalPreviewBytes, lessThan(600000));
    for (final preview in previews.values) {
      expect(preview.length, greaterThan(1000));
      expect(preview[0], 0xff);
      expect(preview[1], 0xd8);
      final decoded = image.decodeJpg(preview);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1200));
      expect(decoded.height, lessThanOrEqualTo(1200));
    }
  });
}

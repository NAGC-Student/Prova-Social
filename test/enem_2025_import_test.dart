import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/answer_key_parser.dart';
import 'package:prova_social/core/import/exam_layout_profile.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/exam_metadata_suggester.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

/// The 2025 ENEM “Prova Verificada” (caderno 1, dia 1, versão azul) kept as a
/// local benchmark: it is the hardest model the importer has to take, because
/// the PDF prints two columns per page, splits the question marker into
/// “Quest ão 04”, tiles a watermark across every sheet, and puts the command of
/// a question in the neighbouring column.
///
/// The file is not committed, so the benchmark runs only on the machine that
/// holds it; every other case of this shape is covered by
/// `test/bancas_import_test.dart`.
final _sample = File('2025_PV_impresso_D1_CD1.pdf');

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test(
    'imports all 90 questions of the 2025 ENEM verified exam',
    () async {
      final bytes = await _sample.readAsBytes();
      final extraction = await const PdfTextExtractor().extract(
        bytes,
        sourceName: _sample.path,
      );
      final pageTexts = extraction.pages
          .map((page) => page.text)
          .toList(growable: false);
      final questions = const QuestionParser().parsePages(pageTexts);
      final quality = const ImportQualityGate().assess(extraction, questions);
      final profile = const ExamLayoutProfiler().profile(pageTexts);
      final metadataPages = extraction.pages
          .take(5)
          .map((page) => '${page.text}\n${page.nativeText}')
          .toList(growable: false);
      final metadata = suggestExamMetadata(
        fileName: _sample.path,
        firstPageText: metadataPages.first,
        pages: metadataPages,
      );

      expect(extraction.pageCount, 32);
      expect(extraction.unreadablePages, 0);
      expect(questions, hasLength(90));
      expect(questions.map((question) => question.number), [
        for (var number = 1; number <= 90; number++) number,
      ]);
      expect(
        questions.every((question) => question.options.length >= 3),
        isTrue,
      );
      expect(
        questions.where((question) => question.options.length == 5).length,
        greaterThanOrEqualTo(85),
      );
      expect(
        questions.map((question) => question.sourcePage).toSet(),
        containsAll(<int>{2, 3, 7, 16, 22, 26, 30}),
      );
      // Furniture must not reach the caderno the user reviews.
      final body = pageTexts.join('\n');
      expect(body, isNot(contains('ENEM2025ENEM2025')));
      expect(body, isNot(contains('010175AZ')));
      expect(body, isNot(matches(RegExp(r'\d{2}/\d{2}/20\d{2} \d{2}:\d{2}'))));
      expect(
        questions.map((question) => question.statement).join(' '),
        isNot(contains('PROVA_SOCIAL_PAGE_')),
      );
      expect(profile.banca, isNull);
      expect(metadata.year, 2025);
      expect(metadata.category, 'Exame nacional');
      expect(metadata.instance, contains('dia'));
      expect(metadata.instance, contains('Caderno 1'));
      expect(metadata.title, startsWith('ENEM 2025'));
      expect(quality.questionsNeedingReview, lessThanOrEqualTo(12));
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: _skipReason,
  );

  test('lê o gabarito do ENEM quando ele vem anexado ao caderno', () {
    const key = [
      'GABARITO OFICIAL',
      '1-B 2-D 3-A 4-C 5-E 6-A 7-D 8-B 9-C 10-E',
      '11-A 12-D 13-B 14-C 15-E 16-A 17-D 18-B 19-C 20-E',
    ];
    final questions = const QuestionParser().parsePages([
      'Questão 01\nQual é o objetivo do texto?\nA primeiro.\nB segundo.\nC terceiro.\nD quarto.\nE quinto.',
      'Questão 02\nE o gênero?\nA narração.\nB descrição.\nC dissertação.\nD carta.\nE poema.',
    ]);
    const keys = AnswerKeyParser();
    final application = keys.apply(keys.parsePages(key), questions);

    expect(application.foundAnything, isTrue);
    expect(application.applied, 2);
    expect(questions.map((question) => question.correctIndex), [1, 3]);
  });
}

String? get _skipReason => _sample.existsSync()
    ? null
    : 'Caderno do ENEM 2025 não está nesta máquina (arquivo não versionado).';

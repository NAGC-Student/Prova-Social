import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/ocr_recognition.dart';
import 'package:prova_social/core/import/ocr_router.dart';
import 'package:prova_social/core/import/ocr_service.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

/// This is an OCR-path test, not a native-text shortcut: the real ITA 2026
/// PDF has no text layer, so the fake service stands in for the platform OCR
/// plugin that is unavailable in the Linux Flutter test runner.
class _ItaOcrFixtureService extends OcrService {
  var calls = 0;

  @override
  Set<OcrEngine> get availableEngines => const {OcrEngine.paddleOcr};

  @override
  Future<OcrRecognition> recognizePage(
    dynamic page, {
    required OcrEngine engine,
  }) async {
    calls++;
    if (calls != 1) {
      return OcrRecognition(engine: engine, text: '');
    }
    final text = StringBuffer('Questão 1. Enunciado OCR do ITA.\n');
    for (var number = 1; number <= 48; number++) {
      if (number > 1) text.write('\nQuestão $number. Enunciado OCR do ITA.\n');
      for (final letter in ['A', 'B', 'C', 'D', 'E']) {
        text.writeln('$letter ( ) alternativa OCR $letter.');
      }
    }
    return OcrRecognition(
      engine: engine,
      text: text.toString(),
      confidence: .93,
    );
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  test('passa PDF escaneado pelo OCR até o parser', () async {
    final pdf = await File('build/qa/military-exams/ita/2026-fase-1.pdf')
        .readAsBytes();
    final ocr = _ItaOcrFixtureService();
    final progress = <({int page, int total, PdfPageTextSource source})>[];
    final extraction = await PdfTextExtractor(ocrFactory: () => ocr).extract(
      pdf,
      onPageProgress: (page, total) {
        progress.add((
          page: page.pageNumber,
          total: total,
          source: page.source,
        ));
      },
    );
    final questions = const QuestionParser().parsePages(
      extraction.pages.map((page) => page.text).toList(growable: false),
    );

    expect(extraction.pages.first.source, PdfPageTextSource.onDeviceOcr);
    expect(extraction.ocrPages, greaterThanOrEqualTo(1));
    expect(questions, hasLength(48));
    expect(questions.every((question) => question.options.length == 5), isTrue);
    expect(ocr.calls, greaterThan(0));
    expect(progress, hasLength(extraction.pageCount));
    expect(progress.last.total, extraction.pageCount);
    expect(
      progress.where((item) => item.source == PdfPageTextSource.onDeviceOcr),
      isNotEmpty,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

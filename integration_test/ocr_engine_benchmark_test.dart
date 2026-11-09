import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:prova_social/core/import/ocr_layout_orderer.dart';
import 'package:prova_social/core/import/ocr_router.dart';
import 'package:prova_social/core/import/ocr_service.dart';
import 'package:prova_social/core/import/page_furniture_filter.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/core/import/text_normalizer.dart';

/// Benchmark estrutural dos motores de OCR em um Android real.
///
/// Não mede acurácia de caractere nesta rodada: mede tempo por página,
/// quantidade de questões e alternativas detectadas, ordem e falhas
/// estruturais. O fixture padrão é o PDF sintético de 80 questões, que é
/// permitido para teste e proibido como conteúdo de produto (ADR-0007).
const _pdfBase64 = String.fromEnvironment('OCR_BENCHMARK_PDF_BASE64');
const _pdfPath = String.fromEnvironment('OCR_BENCHMARK_PDF_PATH');
const _expectedQuestions = int.fromEnvironment(
  'OCR_BENCHMARK_EXPECTED_QUESTIONS',
  defaultValue: 80,
);
const _expectedOptions = int.fromEnvironment(
  'OCR_BENCHMARK_EXPECTED_OPTIONS',
  defaultValue: 400,
);
const _reportMarker = 'OCR_BENCHMARK_REPORT:';
const _timeout = Timeout(Duration(minutes: 20));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('benchmark estrutural do PaddleOCR', (tester) async {
    await _run('paddleOcr', OcrEngine.paddleOcr);
  }, timeout: _timeout);

  testWidgets('benchmark estrutural do ML Kit', (tester) async {
    await _run('mlKit', OcrEngine.mlKit);
  }, timeout: _timeout);
}

Future<void> _run(String label, OcrEngine engine) async {
  final bytes = await _loadPdf();
  Map<String, Object?> report;
  try {
    report = await _benchmark(engine, bytes);
  } catch (error, stackTrace) {
    _emit({
      'engine': label,
      'error': '$error',
      'stack': '$stackTrace',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    rethrow;
  }
  _emit(report);
  debugPrint(
    '[$label] ${report['pages']} páginas, '
    '${report['questionsDetected']}/$_expectedQuestions questões, '
    '${report['optionsDetected']}/$_expectedOptions alternativas, '
    'ordem=${report['orderCorrect']}, '
    '${report['totalMilliseconds']} ms',
  );
  for (final failure in report['structuralFailures'] as List<String>) {
    debugPrint('[$label] falha estrutural: $failure');
  }

  // A execução precisa produzir um relatório mesmo quando a qualidade é ruim;
  // o objetivo desta rodada é medir, não aprovar o motor.  expect(report['pages'], greaterThan(0));
}

Future<Uint8List> _loadPdf() async {
  if (_pdfBase64.isNotEmpty) {
    try {
      return base64Decode(_pdfBase64);
    } on FormatException catch (error) {
      throw StateError('OCR_BENCHMARK_PDF_BASE64 não é base64 válido: $error');
    }
  }
  if (_pdfPath.isNotEmpty) {
    final file = File(_pdfPath);
    if (!await file.exists()) {
      throw StateError('PDF do benchmark não encontrado: ${file.path}');
    }
    return file.readAsBytes();
  }
  throw StateError(
    'Nenhum PDF de benchmark informado. Use qa/run_ocr_benchmark.sh ou '
    'defina OCR_BENCHMARK_PDF_BASE64/OCR_BENCHMARK_PDF_PATH.',
  );
}

Future<Map<String, Object?>> _benchmark(
  OcrEngine engine,
  Uint8List bytes,
) async {
  await PdfTextExtractor.initialize();
  final ocr = OcrService();
  if (!ocr.availableEngines.contains(engine)) {
    throw StateError(
      'O motor $engine não está disponível neste aparelho '
      '(disponíveis: ${ocr.availableEngines.join(', ')}).',
    );
  }

  final document = await PdfDocument.openData(
    bytes,
    sourceName: 'ocr-benchmark.pdf',
  );
  final texts = <String>[];
  final pageTimings = <Map<String, Object?>>[];
  final total = Stopwatch()..start();
  try {
    for (final page in document.pages) {
      final pageTimer = Stopwatch()..start();
      final recognition = await ocr.recognizePage(page, engine: engine);
      pageTimer.stop();
      final ordered = recognition.regions.isEmpty
          ? recognition.text.trim()
          : const OcrLayoutOrderer().text(recognition.regions).trim();
      texts.add(ordered);
      pageTimings.add({
        'page': page.pageNumber,
        'milliseconds': pageTimer.elapsedMilliseconds,
        'characters': ordered.length,
        'regions': recognition.regions.length,
        'confidence': recognition.confidence,
      });
    }
  } finally {
    await document.dispose();
    await ocr.dispose();
  }
  total.stop();

  final furniture = const PageFurnitureFilter().apply(texts);
  final cleaned = [
    for (final page in furniture.pages) ExamTextNormalizer.normalize(page),
  ];
  final questions = const QuestionParser().parsePages(cleaned);
  final numbers = questions.map((question) => question.number).toList();
  final detectedOptions = questions.fold<int>(
    0,
    (sum, question) => sum + question.options.length,
  );
  final numbered = numbers.whereType<int>().toList();
  final orderCorrect =
      questions.isNotEmpty &&
      numbers.every((number) => number != null) &&
      List.generate(
        questions.length,
        (index) => numbers[index] == index + 1,
      ).every((value) => value);
  final duplicates = numbered.length != numbered.toSet().length;
  final questionsWithoutOptions = questions
      .where((question) => question.options.length < 2)
      .length;
  final emptyStatements = questions
      .where((question) => question.statement.trim().length < 10)
      .length;
  final emptyPages = pageTimings
      .where((page) => (page['characters'] as int) == 0)
      .length;

  final failures = <String>[];
  if (questions.length != _expectedQuestions) {
    failures.add(
      'questões detectadas: ${questions.length}; esperado: '
      '$_expectedQuestions',
    );
  }
  if (_expectedOptions > 0 && detectedOptions != _expectedOptions) {
    failures.add(
      'alternativas detectadas: $detectedOptions; esperado: '
      '$_expectedOptions',
    );
  }
  if (!orderCorrect) {
    failures.add('numeração das questões ausente ou fora de ordem');
  }
  if (duplicates) failures.add('numeração de questão duplicada');
  if (questionsWithoutOptions > 0) {
    failures.add(
      '$questionsWithoutOptions questão(ões) com menos de 2 alternativas',
    );
  }
  if (emptyStatements > 0) {
    failures.add('$emptyStatements questão(ões) com enunciado vazio ou curto');
  }
  if (emptyPages > 0) {
    failures.add('$emptyPages página(s) sem texto reconhecido');
  }

  return {
    'engine': engine.name,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'pages': pageTimings.length,
    'totalMilliseconds': total.elapsedMilliseconds,
    'averageMillisecondsPerPage': pageTimings.isEmpty
        ? 0
        : (total.elapsedMilliseconds / pageTimings.length).round(),
    'pageTimings': pageTimings,
    'questionsDetected': questions.length,
    'expectedQuestions': _expectedQuestions,
    'optionsDetected': detectedOptions,
    'expectedOptions': _expectedOptions,
    'orderCorrect': orderCorrect,
    'duplicateQuestionNumbers': duplicates,
    'questionsWithoutOptions': questionsWithoutOptions,
    'emptyStatements': emptyStatements,
    'emptyPages': emptyPages,
    'structuralFailures': failures,
  };
}

void _emit(Map<String, Object?> report) {
  // O script qa/run_ocr_benchmark.sh extrai esta linha do log do teste.
  // ignore: avoid_print
  print('$_reportMarker${jsonEncode(report)}');
}

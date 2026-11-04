import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/exam_layout_profile.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

const _root = '/home/nikolas/Corpus/prova-social-corpus/datasets/raw';

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('corpus inteiro pelo parser Dart', () async {
    final files =
        Directory(_root)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.pdf'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final report = <Map<String, Object?>>[];
    for (final file in files) {
      final relative = file.path.substring(_root.length + 1);
      final name = file.uri.pathSegments.last;
      final stopwatch = Stopwatch()..start();
      try {
        final extraction = await const PdfTextExtractor().extract(
          await file.readAsBytes(),
          sourceName: name,
        );
        final pages = extraction.pages.map((page) => page.text).toList();
        final questions = const QuestionParser().parsePages(pages);
        const gate = ImportQualityGate();
        gate.markNumberingIssues(questions);
        final quality = gate.assess(extraction, questions);
        final profile = const ExamLayoutProfiler().profile(pages);
        final numbers = questions
            .map((question) => question.number)
            .whereType<int>()
            .toList();
        final max = numbers.isEmpty ? 0 : numbers.reduce((a, b) => a > b ? a : b);
        final seen = numbers.toSet();
        final missing = [
          for (var number = 1; number <= max; number++)
            if (!seen.contains(number)) number,
        ];
        final duplicates = <String, int>{};
        final counts = <int, int>{};
        for (final number in numbers) {
          counts[number] = (counts[number] ?? 0) + 1;
        }
        for (final entry in counts.entries) {
          if (entry.value > 1) duplicates[entry.key.toString()] = entry.value;
        }
        final data = <String, Object?>{
          'file': relative,
          'pages': extraction.pageCount,
          'questions': questions.length,
          'missing': missing,
          'duplicates': duplicates,
          'emptyOptions': questions
              .where((question) => question.options.isEmpty)
              .length,
          'underFourOptions': questions
              .where(
                (question) =>
                    question.options.isNotEmpty && question.options.length < 4,
              )
              .length,
          'overFiveOptions': questions
              .where((question) => question.options.length > 5)
              .length,
          'profile': profile.label,
          'quality': quality.status.name,
          'needReview': quality.questionsNeedingReview,
          'numberingIssues': quality.numberingIssues,
          'seconds': stopwatch.elapsedMilliseconds / 1000,
        };
        report.add(data);
        stdout.writeln(jsonEncode(data));
      } catch (error, stack) {
        final data = <String, Object?>{
          'file': relative,
          'error': error.toString(),
          'seconds': stopwatch.elapsedMilliseconds / 1000,
        };
        report.add(data);
        stdout.writeln(jsonEncode(data));
        stdout.writeln(
          stack.toString().split('\n').take(3).join('\n'),
        );
      }
    }
    File('/tmp/corpus_bench_probe.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    stdout.writeln('files=${files.length}');
  }, timeout: const Timeout(Duration(minutes: 60)));
}

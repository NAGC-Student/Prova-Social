import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/answer_key_parser.dart';
import 'package:prova_social/core/import/exam_layout_profile.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/core/import/text_normalizer.dart';

const folder = '/home/nikolas/Downloads/Provas';

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('probe do corpus', () async {
    final files = Directory(folder)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.pdf'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final report = StringBuffer();
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      report.writeln('################ $name');
      try {
        final bytes = await file.readAsBytes();
        final extraction = await const PdfTextExtractor().extract(
          bytes,
          sourceName: name,
        );
        final pageTexts = extraction.pages
            .map((page) => page.text)
            .toList(growable: false);
        final questions = const QuestionParser().parsePages(pageTexts);
        const keys = AnswerKeyParser();
        final key = keys.parsePages(pageTexts);
        final application = key.isEmpty
            ? null
            : keys.apply(key, questions);
        const gate = ImportQualityGate();
        gate.markNumberingIssues(questions);
        final quality = gate.assess(extraction, questions);
        final profile = const ExamLayoutProfiler().profile(pageTexts);

        final histogram = <int, int>{};
        for (final question in questions) {
          histogram[question.options.length] =
              (histogram[question.options.length] ?? 0) + 1;
        }
        final numbers = questions
            .map((question) => question.number)
            .whereType<int>()
            .toSet();
        final max = numbers.isEmpty ? 0 : numbers.reduce(
          (a, b) => a > b ? a : b,
        );
        final missing = [
          for (var number = 1; number <= max; number++)
            if (!numbers.contains(number)) number,
        ];

        report.writeln(
          'pages=${extraction.pageCount} withText=${extraction.pagesWithText} '
          'ocr=${extraction.ocrPages} unreadable=${extraction.unreadablePages}',
        );
        report.writeln(
          'profile=${profile.label} banca=${profile.banca} '
          'layout=${profile.layout.name}',
        );
        report.writeln(
          'questions=${questions.length} max=$max missing=${_range(missing)}',
        );
        report.writeln('options=$histogram');
        final counts = <int, int>{};
        for (final q in questions) {
          final n = q.number;
          if (n != null) counts[n] = (counts[n] ?? 0) + 1;
        }
        report.writeln(
          'duplicated=${counts.entries.where((e) => e.value > 1).toList()..sort()}',
        );
        for (final q in questions.where((q) => q.options.isEmpty)) {
          report.writeln(
            '  EMPTY #${q.number} page=${q.sourcePage} pos=${q.sourcePosition} '
            'conf=${q.confidence.toStringAsFixed(2)} warn=${q.warning} '
            'stmt=${q.statement.replaceAll('\n', ' ').substring(0, 120)}',
          );
        }
        report.writeln(
          'quality=${quality.status.name} needReview='
          '${quality.questionsNeedingReview} reasons=${quality.reasons}',
        );
        report.writeln(
          'key: heading=${key.heading} entries=${key.length} '
          'pages=${key.pages} applied=${application?.applied} '
          'keyable=${application?.keyable} '
          'withoutKey=${_range(application?.withoutKey ?? const [])} '
          'unmatched=${_range(application?.unmatched ?? const [])}',
        );
        final warned = questions
            .where((question) => question.warning != null)
            .toList();
        report.writeln('warnings=${warned.length}');
        final dump = StringBuffer();
        for (final question in questions) {
          dump.writeln(
            '#${question.number} page=${question.sourcePage} '
            'opts=${question.options.length} fmt=${question.format.name} '
            'conf=${question.confidence.toStringAsFixed(2)} '
            'correct=${question.correctIndex} '
            'warn=${question.warning} '
            'stmt="${question.statement.replaceAll('\n', ' ')}"',
          );
        }
        File('/tmp/probe_$name.txt').writeAsStringSync(dump.toString());
        final pages = StringBuffer();
        for (var index = 0; index < pageTexts.length; index++) {
          pages.writeln('===== PAGE ${index + 1} =====');
          pages.writeln(pageTexts[index]);
        }
        File('/tmp/probe_pages_$name.txt').writeAsStringSync(pages.toString());
      } catch (error, stack) {
        report.writeln('ERROR $error');
        report.writeln('$stack'.split('\n').take(6).join('\n'));
      }
      report.writeln('');
    }
    File('/tmp/probe_report.txt').writeAsStringSync(report.toString());
    stdout.write(report);
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('sonda da página 23 do aluno_oficial', () async {
    final file = File('$folder/aluno_oficial.pdf');
    final extraction = await const PdfTextExtractor().extract(
      await file.readAsBytes(),
      sourceName: file.path,
    );
    final pages = extraction.pages.map((page) => page.text).toList();
    final normalized = ExamTextNormalizer.normalize(pages[22]);
    stdout.writeln('--- NORMALIZED PAGE 23 ---');
    for (final line in normalized.split('\n')) {
      stdout.writeln('[${line.length}] $line');
    }
    final questions = const QuestionParser().parsePages(pages);
    stdout.writeln('--- NUMBERS ---');
    stdout.writeln(
      questions.map((q) => q.number).toList().join(','),
    );
    final slice = const QuestionParser().parsePages([pages[22]]);
    stdout.writeln('--- PAGE 23 ALONE ---');
    for (final q in slice) {
      stdout.writeln(
        '#${q.number} opts=${q.options.length} conf=${q.confidence} '
        'warn=${q.warning} stmt=${q.statement.replaceAll('\n', ' ').substring(0, 60)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('sonda das páginas 21-23 do cadete_pm', () async {
    final file = File('$folder/cadete_pm.pdf');
    final extraction = await const PdfTextExtractor().extract(
      await file.readAsBytes(),
      sourceName: file.path,
    );
    final pages = extraction.pages.map((page) => page.text).toList();
    for (var page = 20; page <= 22; page++) {
      stdout.writeln('--- NORMALIZED PAGE ${page + 1} ---');
      var index = 0;
      for (final line in ExamTextNormalizer.normalize(pages[page]).split('\n')) {
        stdout.writeln('${index++}: $line');
      }
    }
    for (var end = 21; end <= 23; end++) {
      final slice = const QuestionParser().parsePages(
        pages.sublist(0, end),
      );
      stdout.writeln(
        '--- 1..$end -> ${slice.map((q) => q.number).join(',')} ',
      );
      if (end == 22) {
        for (final q in slice.skip(55)) {
          final stmt = q.statement.replaceAll('\n', ' ');
          stdout.writeln(
            '  #${q.number} page=${q.sourcePage} pos=${q.sourcePosition} '
            'opts=${q.options.length} conf=${q.confidence} '
            'warn=${q.warning} stmt=${stmt.substring(0, stmt.length < 90 ? stmt.length : 90)} '
            'opts0=${q.options.take(2).map((o) => o.length < 30 ? o : "${o.substring(0, 30)}…").join(" | ")}',
          );
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

String _range(List<int> numbers) {
  if (numbers.length <= 12) return '$numbers';
  return '${numbers.take(12).toList()}…(${numbers.length})';
}

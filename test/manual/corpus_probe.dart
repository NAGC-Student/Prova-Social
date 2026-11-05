import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/answer_key_parser.dart';
import 'package:prova_social/core/import/exam_layout_profile.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/core/import/text_normalizer.dart';

import 'probe_env.dart';

const _rootVariable = 'PROVA_SOCIAL_PROVAS_DIR';

void main() {
  final folder = probeRoot(_rootVariable);
  final skipReason = probeSkipReason(_rootVariable);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('probe do corpus', skip: folder == null ? skipReason : false, () async {
    final files =
        Directory(folder!)
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
        final application = key.isEmpty ? null : keys.apply(key, questions);
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
        final max = numbers.isEmpty
            ? 0
            : numbers.reduce((a, b) => a > b ? a : b);
        final missing = [
          for (var number = 1; number <= max; number++)
            if (!numbers.contains(number)) number,
        ];
        final counts = <int, int>{};
        for (final question in questions) {
          final number = question.number;
          if (number != null) counts[number] = (counts[number] ?? 0) + 1;
        }
        final duplicated =
            counts.entries.where((entry) => entry.value > 1).toList()..sort();
        final empty = questions
            .where((question) => question.options.isEmpty)
            .toList();
        final warned = questions
            .where((question) => question.warning != null)
            .toList();

        report.writeln(
          'pages=${extraction.pageCount} withText=${extraction.pagesWithText} '
          'ocr=${extraction.ocrPages} unreadable=${extraction.unreadablePages}',
        );
        report.writeln(
          'profile=${profile.label} banca=${profile.banca} '
          'layout=${profile.layout.name}',
        );
        report.writeln(
          'questions=${questions.length} max=$max missing=${range(missing)}',
        );
        report.writeln('options=$histogram duplicated=$duplicated');
        report.writeln(
          'emptyOptions=${empty.length} warnings=${warned.length}',
        );
        report.writeln(
          'quality=${quality.status.name} needReview='
          '${quality.questionsNeedingReview} reasons=${quality.reasons}',
        );
        report.writeln(
          'key: heading=${key.heading} entries=${key.length} '
          'pages=${key.pages} applied=${application?.applied} '
          'keyable=${application?.keyable} '
          'withoutKey=${range(application?.withoutKey ?? const [])} '
          'unmatched=${range(application?.unmatched ?? const [])}',
        );

        final questionsDump = StringBuffer();
        for (final question in questions) {
          questionsDump.writeln(
            '#${question.number} page=${question.sourcePage} '
            'pos=${question.sourcePosition} '
            'opts=${question.options.length} fmt=${question.format.name} '
            'conf=${question.confidence.toStringAsFixed(2)} '
            'correct=${question.correctIndex} warn=${question.warning} '
            'stmt="${clip(question.statement, 4000)}"',
          );
        }
        probeFile('questions_$name.txt')
            .writeAsStringSync(questionsDump.toString());

        final pagesDump = StringBuffer();
        for (var index = 0; index < pageTexts.length; index++) {
          pagesDump.writeln('===== PAGE ${index + 1} =====');
          pagesDump.writeln(pageTexts[index]);
        }
        probeFile('pages_$name.txt').writeAsStringSync(pagesDump.toString());

        final reviewDump = StringBuffer();
        for (final question in empty) {
          reviewDump.writeln(
            'EMPTY #${question.number} page=${question.sourcePage} '
            'pos=${question.sourcePosition} '
            'conf=${question.confidence.toStringAsFixed(2)} '
            'warn=${question.warning} stmt="${clip(question.statement, 120)}"',
          );
        }
        for (final question in warned) {
          reviewDump.writeln(
            'WARN #${question.number} page=${question.sourcePage} '
            'warn=${question.warning} stmt="${clip(question.statement, 120)}"',
          );
        }
        probeFile('review_$name.txt').writeAsStringSync(reviewDump.toString());
      } catch (error, stack) {
        report.writeln('ERROR $error');
        report.writeln(stack.toString().split('\n').take(6).join('\n'));
      }
      report.writeln('');
    }
    final reportFile = probeFile('corpus_report.txt')
      ..writeAsStringSync(report.toString());
    stdout.write(report);
    stdout.writeln('textos das provas: ${probeOutputDirectory().path}');
    stdout.writeln('relatório: ${reportFile.path}');
  }, timeout: const Timeout(Duration(minutes: 20)));

  test(
    'sonda da página 23 do aluno_oficial',
    skip: folder == null ? skipReason : false,
    () async {
      final file = File('$folder${Platform.pathSeparator}aluno_oficial.pdf');
      if (!await file.exists()) {
        stdout.writeln('PDF ausente: ${file.path}');
        return;
      }
      final extraction = await const PdfTextExtractor().extract(
        await file.readAsBytes(),
        sourceName: file.path,
      );
      final pages = extraction.pages.map((page) => page.text).toList();
      final buffer = StringBuffer();
      if (pages.length < 23) {
        buffer.writeln('documento com ${pages.length} páginas');
      } else {
        var index = 0;
        for (final line in ExamTextNormalizer.normalize(
          pages[22],
        ).split('\n')) {
          buffer.writeln('${index++}: [${line.length}] $line');
        }
        final questions = const QuestionParser().parsePages(pages);
        buffer.writeln(
          '--- NUMBERS --- ${questions.map((q) => q.number).join(',')}',
        );
        for (final question in const QuestionParser().parsePages([pages[22]])) {
          buffer.writeln(
            '#${question.number} opts=${question.options.length} '
            'conf=${question.confidence} warn=${question.warning} '
            'stmt="${clip(question.statement, 60)}"',
          );
        }
      }
      final output = probeFile('sonda_aluno_oficial_p23.txt')
        ..writeAsStringSync(buffer.toString());
      stdout.writeln('páginas=${pages.length} → ${output.path}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'sonda das páginas 21-23 do cadete_pm',
    skip: folder == null ? skipReason : false,
    () async {
      final file = File('$folder${Platform.pathSeparator}cadete_pm.pdf');
      if (!await file.exists()) {
        stdout.writeln('PDF ausente: ${file.path}');
        return;
      }
      final extraction = await const PdfTextExtractor().extract(
        await file.readAsBytes(),
        sourceName: file.path,
      );
      final pages = extraction.pages.map((page) => page.text).toList();
      final buffer = StringBuffer();
      for (var page = 20; page <= 22; page++) {
        if (page >= pages.length) {
          buffer.writeln('--- página ${page + 1} inexistente');
          continue;
        }
        buffer.writeln('--- NORMALIZED PAGE ${page + 1} ---');
        var index = 0;
        for (final line in ExamTextNormalizer.normalize(
          pages[page],
        ).split('\n')) {
          buffer.writeln('${index++}: $line');
        }
      }
      for (var end = 21; end <= 23; end++) {
        if (end > pages.length) continue;
        final slice = const QuestionParser().parsePages(pages.sublist(0, end));
        buffer.writeln(
          '--- 1..$end -> ${slice.map((q) => q.number).join(',')}',
        );
        if (end == 22) {
          for (final question in slice.skip(55)) {
            buffer.writeln(
              '#${question.number} page=${question.sourcePage} '
              'pos=${question.sourcePosition} opts=${question.options.length} '
              'conf=${question.confidence} warn=${question.warning} '
              'stmt="${clip(question.statement, 90)}" '
              'opts0=${question.options.take(2).map((o) => clip(o, 30)).join(" | ")}',
            );
          }
        }
      }
      final output = probeFile('sonda_cadete_pm_p21_23.txt')
        ..writeAsStringSync(buffer.toString());
      stdout.writeln('páginas=${pages.length} → ${output.path}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

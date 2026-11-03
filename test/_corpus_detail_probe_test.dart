import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

const _root = '/home/nikolas/Corpus/prova-social-corpus/datasets/raw';
const _files = <String>[
  'fuvest/2025/doc_f512449b47ac31abe1ae.pdf',
  'fuvest/2026/doc_93b417ad6ea7e81a3b6a.pdf',
  'quadrix/2026/doc_14c00ad352af692f643a.pdf',
  'quadrix/2026/doc_9a7a93d142b202fbc8aa.pdf',
  'cebraspe/2021/doc_abcc7422a40b7d19017c.pdf',
  'cebraspe/2021/doc_ef6bf141a96ee5ab57f5.pdf',
  'fgv/2026/doc_0849bc2d88ab9f5a4137.pdf',
  'quadrix/2026/doc_19f807dfd6ea404f93a1.pdf',
  'quadrix/2026/doc_627e02bc4d4414279b76.pdf',
];

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('detalhe de documentos do corpus', () async {
    final buffer = StringBuffer();
    for (final relative in _files) {
      final file = File('$_root/$relative');
      final extraction = await const PdfTextExtractor().extract(
        await file.readAsBytes(),
        sourceName: file.uri.pathSegments.last,
      );
      final pages = extraction.pages.map((page) => page.text).toList();
      final questions = const QuestionParser().parsePages(pages);
      buffer.writeln('===== $relative pages=${pages.length} q=${questions.length}');
      for (final question in questions) {
        buffer.writeln(
          jsonEncode({
            'n': question.number,
            'format': question.format.name,
            'opts': question.options.length,
            'page': question.sourcePage,
            'statement': question.statement
                .replaceAll('\n', ' ')
                .substring(
                  0,
                  question.statement.length < 90
                      ? question.statement.length
                      : 90,
                ),
            'options': question.options
                .map(
                  (option) => option.replaceAll('\n', ' ').substring(
                    0,
                    option.length < 60 ? option.length : 60,
                  ),
                )
                .toList(),
          }),
        );
      }
    }
    File('/tmp/corpus_detail.txt').writeAsStringSync(buffer.toString());
    stdout.writeln('detail written');
  }, timeout: const Timeout(Duration(minutes: 30)));
}

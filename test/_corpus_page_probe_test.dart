import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';

const _root = '/home/nikolas/Corpus/prova-social-corpus/datasets/raw';
const _files = <String>[
  'quadrix/2026/doc_14c00ad352af692f643a.pdf',
  'fuvest/2025/doc_f512449b47ac31abe1ae.pdf',
];

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('paginas como o extrator entrega', () async {
    final buffer = StringBuffer();
    for (final relative in _files) {
      final file = File('$_root/$relative');
      final extraction = await const PdfTextExtractor().extract(
        await file.readAsBytes(),
        sourceName: file.uri.pathSegments.last,
      );
      buffer.writeln('===== $relative');
      for (final page in extraction.pages) {
        buffer.writeln(
          '--- page ${page.pageNumber} source=${page.source.name} '
          'chars=${page.text.length} route=${page.route.name} '
          'warning=${page.warning}',
        );
        final text = page.text;
        buffer.writeln(text);
      }
    }
    File('/tmp/corpus_page_text.txt').writeAsStringSync(buffer.toString());
    stdout.writeln('page text written');
  }, timeout: const Timeout(Duration(minutes: 30)));
}

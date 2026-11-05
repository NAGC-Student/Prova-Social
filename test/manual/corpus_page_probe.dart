import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';

import 'probe_env.dart';

const _rootVariable = 'PROVA_SOCIAL_CORPUS_ROOT';

const _files = <String>[
  'quadrix/2026/doc_14c00ad352af692f643a.pdf',
  'fuvest/2025/doc_f512449b47ac31abe1ae.pdf',
];

void main() {
  final root = probeRoot(_rootVariable);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test(
    'paginas como o extrator entrega',
    skip: root == null ? probeSkipReason(_rootVariable) : false,
    () async {
      final buffer = StringBuffer();
      var analysed = 0;
      for (final relative in _files) {
        final file = File('$root${Platform.pathSeparator}$relative');
        if (!await file.exists()) {
          stdout.writeln('ausente: $relative');
          continue;
        }
        final extraction = await const PdfTextExtractor().extract(
          await file.readAsBytes(),
          sourceName: file.uri.pathSegments.last,
        );
        analysed++;
        buffer.writeln('===== $relative');
        for (final page in extraction.pages) {
          buffer.writeln(
            '--- page ${page.pageNumber} source=${page.source.name} '
            'chars=${page.text.length} route=${page.route.name} '
            'warning=${page.warning}',
          );
          buffer.writeln(page.text);
        }
      }
      final output = probeFile('corpus_page_text.txt')
        ..writeAsStringSync(buffer.toString());
      stdout.writeln('documentos=$analysed/${_files.length} → ${output.path}');
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );
  @Timeout(Duration(minutes: 8))
  testWidgets('extrair texto ESA 2024 para analise de layout', (tester) async {
    final path =
        'build/qa/military-exams/exercito/esa-2024-prova-geral.pdf';
    final bytes = await File(path).readAsBytes();
    print('===== ESA 2024 =====');
    final result = await const PdfTextExtractor().extract(
      bytes,
      sourceName: path,
    );
    print(
      'pages=${result.pageCount} pagesWithText=${result.pagesWithText} unreadable=${result.unreadablePages}',
    );
    for (final page in result.pages) {
      print(
        '--- page ${page.pageNumber} source=${page.source} chars=${page.text.length} warning=${page.warning} ---',
      );
      print(page.text);
    }
  });
}

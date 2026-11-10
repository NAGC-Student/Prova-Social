import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/core/import/visual_option_image_extractor.dart';

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test(
    'crops formula choices as image options in the VUNESP 2024 PDF',
    () async {
      final corpus = await File('test/fixtures/import_corpus.json')
          .readAsString();
      final pdf = await File('test/fixtures/vunesp_2024_pm_sp.pdf')
          .readAsBytes();
      final extraction = await const PdfTextExtractor().extract(pdf);
      final questions = const QuestionParser().parsePages(
        extraction.pages.map((page) => page.text).toList(growable: false),
      );

      final crops = await const VisualOptionImageExtractor().extract(
        pdf,
        questions,
      );

      for (final number in [53, 54, 79, 80]) {
        final question = questions.singleWhere((item) => item.number == number);
        for (var option = 0; option < question.options.length; option++) {
          expect(
            crops['${question.id}:$option'],
            isNotNull,
            reason: 'Questão $number, alternativa ${option + 1}',
          );
        }
      }
      expect(crops.values.every((image) => image.length > 500), isTrue);
      for (final question in questions.where(
        (item) => [53, 54, 79, 80].contains(item.number),
      )) {
        for (var option = 0; option < question.options.length; option++) {
          final decoded = image.decodeJpg(crops['${question.id}:$option']!);
          expect(decoded, isNotNull);
          expect(decoded!.width, lessThan(900));
        }
      }

      final debugDirectory =
          Platform.environment['PROVA_SOCIAL_DEBUG_VISUAL_CROPS'];
      if (debugDirectory != null && debugDirectory.trim().isNotEmpty) {
        final directory = Directory(debugDirectory)
          ..createSync(recursive: true);
        for (final question in questions.where(
          (item) => [53, 54, 79, 80].contains(item.number),
        )) {
          for (var option = 0; option < question.options.length; option++) {
            final bytes = crops['${question.id}:$option'];
            if (bytes == null) continue;
            File(
              '${directory.path}/q${question.number}-option${option + 1}.jpg',
            ).writeAsBytesSync(bytes);
          }
        }
      }

      // Keep the import_corpus manifest present in this test's working set.
      expect(corpus, contains('user-provided-vunesp-2024-pm-sp'));
    },
  );
}

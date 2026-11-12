import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:prova_social/core/import/imported_document.dart';
import 'package:prova_social/core/import/question_parser.dart' as parser;
import 'package:prova_social/core/import/visual_document_engine/visual_document_engine.dart';

void main() {
  group('VisualDocumentAdapter', () {
    test('adapt converts visual question to ImportedQuestion', () {
      const adapter = VisualDocumentAdapter();
      final visualResult = VisualImportResult(
        pages: [],
        questions: [
          VisualImportedQuestion(
            id: 'q-1',
            number: 1,
            sourcePage: 1,
            statement: [
              VisualBlock(
                type: VisualBlockType.text,
                bounds: VisualRect(left: 10, top: 10, right: 100, bottom: 30),
                text: 'Qual é a capital do Brasil?',
              ),
            ],
            alternatives: [
              VisualAlternative(
                label: 'A',
                content: [
                  VisualBlock(
                    type: VisualBlockType.text,
                    bounds: VisualRect(
                      left: 35,
                      top: 70,
                      right: 100,
                      bottom: 90,
                    ),
                    text: 'Brasília',
                  ),
                ],
              ),
            ],
            format: QuestionFormat.multipleChoice,
            confidence: 0.9,
          ),
        ],
        assets: {},
      );

      final questions = adapter.adapt(visualResult: visualResult);
      expect(questions, hasLength(1));
      expect(questions.first.id, 'q-1');
      expect(questions.first.number, 1);
      expect(questions.first.sourcePage, 1);
      expect(
        questions.first.statement,
        contains('Qual é a capital do Brasil?'),
      );
      expect(questions.first.options, hasLength(1));
      expect(questions.first.options.first, 'Brasília');
    });

    test('adapt stores image assets as optionImageBase64', () {
      const adapter = VisualDocumentAdapter();
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      final asset = VisualAsset(
        id: 'asset-opt-a',
        type: VisualAssetType.optionImage,
        bytes: imageBytes,
        mimeType: 'image/jpeg',
        sourcePage: 1,
      );
      final visualResult = VisualImportResult(
        pages: [],
        questions: [
          VisualImportedQuestion(
            id: 'q-2',
            number: 2,
            sourcePage: 1,
            statement: [
              VisualBlock(
                type: VisualBlockType.text,
                bounds: VisualRect(left: 10, top: 10, right: 100, bottom: 30),
                text: 'Qual é a resposta?',
              ),
            ],
            alternatives: [
              VisualAlternative(
                label: 'A',
                content: [],
                imageAssetId: 'asset-opt-a',
              ),
            ],
            format: QuestionFormat.multipleChoice,
            confidence: 0.8,
          ),
        ],
        assets: {'asset-opt-a': asset},
      );

      final questions = adapter.adapt(visualResult: visualResult);
      expect(questions, hasLength(1));
      expect(questions.first.options, hasLength(1));
      expect(questions.first.options.first, isEmpty);
      expect(
        questions.first.optionImageBase64,
        equals({0: base64Encode(imageBytes)}),
      );
    });
  });
}

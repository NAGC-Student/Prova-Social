import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:prova_social/core/import/visual_document_engine/assemble/visual_question_assembler.dart';
import 'package:prova_social/core/import/visual_document_engine/models/visual_models.dart';

void main() {
  group('VisualQuestionAssembler', () {
    test('assemble returns empty when no anchors', () {
      const assembler = VisualQuestionAssembler();
      final pages = [
        VisualPage(
          number: 1,
          width: 200,
          height: 300,
          imageBytes: Uint8List(0),
          elements: [
            VisualBlock(
              type: VisualBlockType.text,
              bounds: VisualRect(left: 10, top: 10, right: 100, bottom: 30),
              text: 'Texto sem número de questão.',
            ),
          ],
        ),
      ];
      final questions = assembler.assemble(pages);
      expect(questions, isEmpty);
    });

    test('assemble creates question from anchor and following blocks', () {
      const assembler = VisualQuestionAssembler();
      final pages = [
        VisualPage(
          number: 1,
          width: 200,
          height: 300,
          imageBytes: Uint8List(0),
          elements: [
            VisualBlock(
              type: VisualBlockType.text,
              bounds: VisualRect(left: 10, top: 10, right: 100, bottom: 30),
              text: 'Questão 1',
            ),
            VisualBlock(
              type: VisualBlockType.text,
              bounds: VisualRect(left: 10, top: 40, right: 150, bottom: 60),
              text: 'Qual é a capital do Brasil?',
            ),
            VisualBlock(
              type: VisualBlockType.optionLabel,
              bounds: VisualRect(left: 10, top: 70, right: 30, bottom: 90),
              text: 'A',
            ),
            VisualBlock(
              type: VisualBlockType.text,
              bounds: VisualRect(left: 35, top: 70, right: 100, bottom: 90),
              text: 'Brasília',
            ),
            VisualBlock(
              type: VisualBlockType.optionLabel,
              bounds: VisualRect(left: 10, top: 100, right: 30, bottom: 120),
              text: 'B',
            ),
            VisualBlock(
              type: VisualBlockType.text,
              bounds: VisualRect(left: 35, top: 100, right: 100, bottom: 120),
              text: 'São Paulo',
            ),
          ],
        ),
      ];
      final questions = assembler.assemble(pages);
      expect(questions, hasLength(1));
      expect(questions.first.number, 1);
      expect(questions.first.sourcePage, 1);
      expect(questions.first.statementPlainText, contains('Qual é a capital'));
      expect(questions.first.alternatives, hasLength(2));
      expect(questions.first.alternatives.first.label, 'A');
      expect(questions.first.alternatives.first.plainText, 'Brasília');
      expect(questions.first.alternatives.last.label, 'B');
      expect(questions.first.alternatives.last.plainText, 'São Paulo');
    });
  });
}

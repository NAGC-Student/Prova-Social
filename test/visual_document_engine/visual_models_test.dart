import 'package:flutter_test/flutter_test.dart';

import 'package:prova_social/core/import/visual_document_engine/models/visual_models.dart';

void main() {
  group('VisualRect', () {
    test('overlapWith returns 0 when no overlap', () {
      final a = VisualRect(left: 0, top: 0, right: 10, bottom: 10);
      final b = VisualRect(left: 20, top: 20, right: 30, bottom: 30);
      expect(a.overlapWith(b), 0);
    });

    test('overlapWith returns 1 when identical', () {
      final a = VisualRect(left: 0, top: 0, right: 10, bottom: 10);
      final b = VisualRect(left: 0, top: 0, right: 10, bottom: 10);
      expect(a.overlapWith(b), 1);
    });

    test('centerX and centerY are correct', () {
      final rect = VisualRect(left: 0, top: 0, right: 100, bottom: 200);
      expect(rect.centerX, 50);
      expect(rect.centerY, 100);
    });

    test('containsPoint works', () {
      final rect = VisualRect(left: 0, top: 0, right: 10, bottom: 10);
      expect(rect.containsPoint(const VisualPoint(5, 5)), isTrue);
      expect(rect.containsPoint(const VisualPoint(15, 5)), isFalse);
    });
  });

  group('VisualBlock', () {
    test('plainText returns text and children text', () {
      final block = VisualBlock(
        type: VisualBlockType.text,
        bounds: VisualRect(left: 0, top: 0, right: 10, bottom: 10),
        text: 'Olá',
        children: [
          VisualBlock(
            type: VisualBlockType.text,
            bounds: VisualRect(left: 0, top: 10, right: 10, bottom: 20),
            text: 'mundo',
          ),
        ],
      );
      expect(block.plainText, 'Olá mundo');
    });

    test('copyWith creates modified copy', () {
      final original = VisualBlock(
        type: VisualBlockType.text,
        bounds: VisualRect(left: 0, top: 0, right: 10, bottom: 10),
        text: 'original',
        confidence: 0.5,
      );
      final copy = original.copyWith(text: 'modificado', confidence: 0.9);
      expect(copy.text, 'modificado');
      expect(copy.confidence, 0.9);
      expect(copy.type, original.type);
    });

    test('toJson and fromJson round-trip', () {
      final original = VisualBlock(
        type: VisualBlockType.formula,
        bounds: VisualRect(left: 1, top: 2, right: 3, bottom: 4),
        text: 'x = 1',
        assetId: 'asset-1',
        confidence: 0.8,
      );
      final json = original.toJson();
      final restored = VisualBlock.fromJson(json);
      expect(restored.type, VisualBlockType.formula);
      expect(restored.bounds.left, 1);
      expect(restored.bounds.top, 2);
      expect(restored.text, 'x = 1');
      expect(restored.assetId, 'asset-1');
      expect(restored.confidence, 0.8);
    });
  });

  group('VisualAlternative', () {
    test('plainText returns empty when only imageAssetId', () {
      final alt = VisualAlternative(
        label: 'A',
        content: [],
        imageAssetId: 'asset-img',
      );
      expect(alt.plainText, '');
    });

    test('plainText joins content text', () {
      final alt = VisualAlternative(
        label: 'B',
        content: [
          VisualBlock(
            type: VisualBlockType.text,
            bounds: VisualRect(left: 0, top: 0, right: 10, bottom: 10),
            text: 'Alternativa B',
          ),
        ],
      );
      expect(alt.plainText, 'Alternativa B');
    });
  });

  group('VisualImportedQuestion', () {
    test('statementPlainText joins statement blocks', () {
      final question = VisualImportedQuestion(
        id: 'q-1',
        statement: [
          VisualBlock(
            type: VisualBlockType.text,
            bounds: VisualRect(left: 0, top: 0, right: 10, bottom: 10),
            text: 'Considere',
          ),
          VisualBlock(
            type: VisualBlockType.formula,
            bounds: VisualRect(left: 0, top: 10, right: 10, bottom: 20),
            text: 'x = 1',
          ),
        ],
        alternatives: [],
        sourcePage: 1,
      );
      expect(question.statementPlainText, 'Considere x = 1');
    });

    test('toJson and fromJson round-trip', () {
      final original = VisualImportedQuestion(
        id: 'q-1',
        number: 1,
        sourcePage: 1,
        statement: [
          VisualBlock(
            type: VisualBlockType.text,
            bounds: VisualRect(left: 0, top: 0, right: 10, bottom: 10),
            text: 'Enunciado',
          ),
        ],
        alternatives: [
          VisualAlternative(
            label: 'A',
            content: [
              VisualBlock(
                type: VisualBlockType.text,
                bounds: VisualRect(left: 0, top: 0, right: 10, bottom: 10),
                text: 'Opção A',
              ),
            ],
          ),
        ],
        format: QuestionFormat.multipleChoice,
        confidence: 0.9,
      );
      final json = original.toJson();
      final restored = VisualImportedQuestion.fromJson(json);
      expect(restored.id, 'q-1');
      expect(restored.number, 1);
      expect(restored.sourcePage, 1);
      expect(restored.statement.length, 1);
      expect(restored.statement.first.text, 'Enunciado');
      expect(restored.alternatives.length, 1);
      expect(restored.alternatives.first.label, 'A');
      expect(restored.format, QuestionFormat.multipleChoice);
      expect(restored.confidence, 0.9);
    });
  });
}

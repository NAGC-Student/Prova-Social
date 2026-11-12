import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:prova_social/core/import/visual_document_engine/detect/visual_layout_detector.dart';
import 'package:prova_social/core/import/visual_document_engine/models/visual_models.dart';

void main() {
  group('VisualLayoutDetector', () {
    test('detectColumnSplit returns null for single column', () {
      final detector = const VisualLayoutDetector();
      final blocks = [
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 10, right: 100, bottom: 30),
          text: 'Bloco de texto da primeira linha do documento de prova.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 40, right: 100, bottom: 60),
          text: 'Bloco de texto da segunda linha do documento de prova.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 70, right: 100, bottom: 90),
          text: 'Bloco de texto da terceira linha do documento de prova.',
        ),
      ];
      expect(detector.detectColumnSplit(blocks, 200), isNull);
    });

    test('detectColumnSplit finds split for two columns', () {
      final detector = const VisualLayoutDetector();
      final blocks = <VisualBlock>[
        // Left column
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 10, right: 80, bottom: 30),
          text: 'Texto da coluna esquerda primeira linha do documento.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 40, right: 80, bottom: 60),
          text: 'Texto da coluna esquerda segunda linha do documento.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 70, right: 80, bottom: 90),
          text: 'Texto da coluna esquerda terceira linha do documento.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 100, right: 80, bottom: 120),
          text: 'Texto da coluna esquerda quarta linha do documento.',
        ),
        // Right column
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 120, top: 10, right: 190, bottom: 30),
          text: 'Texto da coluna direita primeira linha do documento.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 120, top: 40, right: 190, bottom: 60),
          text: 'Texto da coluna direita segunda linha do documento.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 120, top: 70, right: 190, bottom: 90),
          text: 'Texto da coluna direita terceira linha do documento.',
        ),
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 120, top: 100, right: 190, bottom: 120),
          text: 'Texto da coluna direita quarta linha do documento.',
        ),
      ];
      final split = detector.detectColumnSplit(blocks, 200);
      expect(split, isNotNull);
      expect(split, greaterThan(80));
      expect(split, lessThan(120));
    });

    test('classifyRegions identifies formula', () {
      final detector = const VisualLayoutDetector();
      final blocks = [
        VisualBlock(
          type: VisualBlockType.text,
          bounds: VisualRect(left: 10, top: 10, right: 100, bottom: 30),
          text: 'x = 1 + 2',
        ),
      ];
      final classified = detector.classifyRegions(blocks, 200);
      expect(classified.first.type, VisualBlockType.formula);
    });

    test('classifyRegions preserves option labels', () {
      final detector = const VisualLayoutDetector();
      final blocks = [
        VisualBlock(
          type: VisualBlockType.optionLabel,
          bounds: VisualRect(left: 10, top: 10, right: 30, bottom: 30),
          text: 'A',
        ),
      ];
      final classified = detector.classifyRegions(blocks, 200);
      expect(classified.first.type, VisualBlockType.optionLabel);
    });
  });
}

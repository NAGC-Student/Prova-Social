import '../models/visual_models.dart';

/// Detecta colunas e regiões visuais em uma página renderizada.
class VisualLayoutDetector {
  const VisualLayoutDetector();

  double? detectColumnSplit(List<VisualBlock> blocks, double pageWidth) {
    if (blocks.length < 6) return null;
    final contentBlocks = blocks
        .where((b) => b.text != null && b.text!.trim().length >= 24)
        .toList(growable: false);
    if (contentBlocks.length < 6) return null;

    final leftCount = contentBlocks
        .where((b) => b.bounds.centerX < pageWidth * 0.42)
        .length;
    final rightCount = contentBlocks
        .where((b) => b.bounds.centerX > pageWidth * 0.58)
        .length;
    if (leftCount >= 3 && rightCount >= 3) {
      return pageWidth / 2;
    }

    final centers = contentBlocks.map((b) => b.bounds.centerX).toList()..sort();
    var largestGap = 0.0;
    var splitIndex = -1;
    for (var i = 1; i < centers.length; i++) {
      final gap = centers[i] - centers[i - 1];
      if (gap > largestGap) {
        largestGap = gap;
        splitIndex = i;
      }
    }
    if (splitIndex < 2 || centers.length - splitIndex < 2) return null;
    final splitX = (centers[splitIndex - 1] + centers[splitIndex]) / 2;
    if (largestGap < pageWidth * 0.12 ||
        splitX < pageWidth * 0.25 ||
        splitX > pageWidth * 0.75) {
      return null;
    }
    final leftSupport = contentBlocks
        .where((b) => b.bounds.right <= splitX + pageWidth * 0.04)
        .length;
    final rightSupport = contentBlocks
        .where((b) => b.bounds.left >= splitX - pageWidth * 0.04)
        .length;
    if (leftSupport >= 3 && rightSupport >= 3) return splitX;
    return null;
  }

  List<VisualBlock> classifyRegions(
    List<VisualBlock> blocks,
    double pageWidth,
  ) {
    final classified = <VisualBlock>[];
    for (final block in blocks) {
      if (block.type == VisualBlockType.optionLabel ||
          block.type == VisualBlockType.optionContent) {
        classified.add(block);
        continue;
      }
      classified.add(_classifySingle(block, pageWidth));
    }
    return List.unmodifiable(classified);
  }

  VisualBlock _classifySingle(VisualBlock block, double pageWidth) {
    final text = block.text ?? '';
    final trimmed = text.trim();

    if (_looksLikeFormula(trimmed)) {
      return block.copyWith(
        type: VisualBlockType.formula,
        confidence: (block.confidence * 0.9 + 0.1).clamp(0, 1),
      );
    }

    if (_looksLikeTable(block, pageWidth)) {
      return block.copyWith(
        type: VisualBlockType.table,
        confidence: (block.confidence * 0.9 + 0.1).clamp(0, 1),
      );
    }

    if (_looksLikeGraphic(trimmed, block.bounds, pageWidth)) {
      return block.copyWith(
        type: VisualBlockType.graphic,
        confidence: (block.confidence * 0.85 + 0.15).clamp(0, 1),
      );
    }

    return block;
  }

  bool _looksLikeFormula(String text) {
    if (text.isEmpty) return false;
    final symbols = RegExp(r'[∫∑∆√∝∞≤≥±×÷≈≠→∂∇πθφαβγδεζηικλμνξρστυω]');
    final mathChars = RegExp(r'[=+\-*/^()\[\]{}]');
    final hasSymbols = symbols.hasMatch(text);
    final hasMath = mathChars.allMatches(text).length >= 2;
    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return (hasSymbols || hasMath) && wordCount <= 12;
  }

  bool _looksLikeTable(VisualBlock block, double pageWidth) {
    final text = block.text ?? '';
    final digits = RegExp(r'\d').allMatches(text).length;
    if (text.isNotEmpty && digits / text.length > 0.25 && digits >= 4) {
      return true;
    }
    if (block.bounds.width > pageWidth * 0.5 && digits >= 3) return true;
    return false;
  }

  bool _looksLikeGraphic(String text, VisualRect bounds, double pageWidth) {
    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (wordCount <= 3) {
      final aspect = bounds.width / (bounds.height + 0.001);
      if (aspect > 2.0 ||
          (aspect > 0.8 && aspect < 1.6 && bounds.width > pageWidth * 0.2)) {
        return true;
      }
    }
    return false;
  }
}

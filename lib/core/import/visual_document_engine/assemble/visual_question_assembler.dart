import '../models/visual_models.dart';

/// Reconstroi questões a partir dos blocos visuais de uma ou mais páginas.
class VisualQuestionAssembler {
  const VisualQuestionAssembler();

  List<VisualImportedQuestion> assemble(
    List<VisualPage> pages, {
    List<int>? pageOrder,
  }) {
    final ordered = (pageOrder ?? List.generate(pages.length, (i) => i + 1))
        .map((n) => pages.firstWhere((p) => p.number == n))
        .toList(growable: false);

    final allBlocks = <VisualBlock>[];
    for (var i = 0; i < ordered.length; i++) {
      final page = ordered[i];
      for (final block in page.elements) {
        allBlocks.add(block);
      }
    }

    allBlocks.sort((a, b) {
      final dy = a.bounds.top - b.bounds.top;
      if (dy.abs() > 8) return dy.toInt();
      return a.bounds.left.compareTo(b.bounds.left);
    });

    final questionAnchors = _findQuestionAnchors(allBlocks);
    if (questionAnchors.isEmpty) return const [];

    final questions = <VisualImportedQuestion>[];
    for (var i = 0; i < questionAnchors.length; i++) {
      final anchor = questionAnchors[i];
      final page = _pageForBlock(anchor, ordered);
      final endY = i + 1 < questionAnchors.length
          ? questionAnchors[i + 1].bounds.top
          : double.infinity;
      final endX = i + 1 < questionAnchors.length
          ? questionAnchors[i + 1].bounds.left
          : double.infinity;

      final blocksAfterAnchor = <VisualBlock>[];
      for (final block in allBlocks) {
        if (identical(block, anchor)) continue;
        if (block.bounds.top < anchor.bounds.top - 4) continue;
        if (block.bounds.top >= endY - 4) continue;
        if (block.bounds.centerX < endX - 20 &&
            anchor.bounds.centerX >= endX - 20) {
          continue;
        }
        blocksAfterAnchor.add(block);
      }

      var statementEnd = blocksAfterAnchor.length;
      for (var i = 0; i < blocksAfterAnchor.length; i++) {
        if (_isOptionLabel(blocksAfterAnchor[i])) {
          statementEnd = i;
          break;
        }
      }
      final statementBlocks = blocksAfterAnchor.sublist(0, statementEnd);
      final optionBlocks = blocksAfterAnchor.sublist(statementEnd);

      final alternatives = _groupAlternatives(optionBlocks);

      final statement = _orderBlocks(statementBlocks);
      final number = _extractQuestionNumber(anchor.text ?? '');

      questions.add(
        VisualImportedQuestion(
          id: _stableQuestionId(
            number,
            page.number,
            statementPlainText(statement),
          ),
          number: number,
          sourcePage: page.number,
          statement: statement,
          alternatives: alternatives,
          format: alternatives.isNotEmpty
              ? QuestionFormat.multipleChoice
              : QuestionFormat.unknown,
          confidence: _computeConfidence(statement, alternatives),
          warning: alternatives.isEmpty
              ? 'Alternativas não detectadas automaticamente.'
              : null,
          reviewState: alternatives.isEmpty
              ? QuestionReviewState.needsAttention
              : QuestionReviewState.unreviewed,
        ),
      );
    }

    return List.unmodifiable(questions);
  }

  List<VisualBlock> _findQuestionAnchors(List<VisualBlock> blocks) {
    final anchors = <VisualBlock>[];
    final questionMarker = RegExp(
      r'(?:quest(?:ão|ao)\s*(?:n[º°.]?\s*)?\d{1,4}|\d{1,4}\s*[ªº°]?\s*(?:quest(?:ão|ao))?)',
      caseSensitive: false,
    );
    for (final block in blocks) {
      final text = block.text ?? '';
      if (questionMarker.hasMatch(text) &&
          text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 8) {
        anchors.add(block);
      }
    }
    return List.unmodifiable(anchors);
  }

  bool _isOptionLabel(VisualBlock block) {
    final text = block.text ?? '';
    return RegExp(
      r'^\(?[A-E]\)?(?:\s*\(\))?\s*[.)-]?\s*$',
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  List<VisualAlternative> _groupAlternatives(List<VisualBlock> optionBlocks) {
    if (optionBlocks.isEmpty) return const [];
    optionBlocks.sort((a, b) {
      final dy = a.bounds.top - b.bounds.top;
      if (dy.abs() > 8) return dy.toInt();
      return a.bounds.left.compareTo(b.bounds.left);
    });

    final alternatives = <VisualAlternative>[];
    var currentLabel = 'A'.codeUnitAt(0);
    var currentContent = <VisualBlock>[];
    var imageAssetBlocks = <VisualBlock>[];

    void flush() {
      if (currentContent.isNotEmpty || imageAssetBlocks.isNotEmpty) {
        alternatives.add(
          VisualAlternative(
            label: String.fromCharCode(currentLabel),
            content: List.unmodifiable(currentContent),
            imageAssetId: imageAssetBlocks.isNotEmpty
                ? 'asset-${imageAssetBlocks.first.bounds.left.round()}'
                : null,
          ),
        );
      }
      currentContent = <VisualBlock>[];
      imageAssetBlocks = <VisualBlock>[];
    }

    for (final block in optionBlocks) {
      final text = block.text ?? '';
      final trimmed = text.trim();
      final labelMatch = RegExp(
        r'^\(?([A-E])\)?(?:\s*\(\))?\s*[.)-]?\s*$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (labelMatch != null) {
        flush();
        currentLabel = labelMatch.group(1)!.toUpperCase().codeUnitAt(0);
        final afterLabel = trimmed.substring(labelMatch.end).trim();
        if (afterLabel.isNotEmpty) {
          currentContent.add(block.copyWith(text: afterLabel));
        }
      } else {
        if (block.type == VisualBlockType.image || block.assetId != null) {
          imageAssetBlocks.add(block);
        } else {
          currentContent.add(block);
        }
      }
    }
    flush();
    return List.unmodifiable(alternatives);
  }

  List<VisualBlock> _orderBlocks(List<VisualBlock> blocks) {
    return [...blocks]..sort((a, b) {
      final dy = a.bounds.top - b.bounds.top;
      if (dy.abs() > 8) return dy.toInt();
      return a.bounds.left.compareTo(b.bounds.left);
    });
  }

  int? _extractQuestionNumber(String text) {
    final match = RegExp(r'(\d{1,4})').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  VisualPage _pageForBlock(VisualBlock block, List<VisualPage> pages) {
    for (final page in pages) {
      if (page.elements.any((b) => identical(b, block))) return page;
    }
    return pages.first;
  }

  String _stableQuestionId(int? number, int page, String statement) {
    final fingerprint = _hash(statement.trim());
    return 'vde-q-$page-${number ?? 0}-$fingerprint';
  }

  String _hash(String input) {
    var hash = 5381;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      hash = hash & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String statementPlainText(List<VisualBlock> statement) {
    return statement
        .map((b) => b.plainText)
        .where((t) => t.isNotEmpty)
        .join(' ');
  }

  double _computeConfidence(
    List<VisualBlock> statement,
    List<VisualAlternative> alternatives,
  ) {
    var score = 0.0;
    if (statement.isNotEmpty) score += 0.4;
    if (statement.any((b) => b.plainText.trim().length >= 10)) score += 0.2;
    if (alternatives.length >= 2) score += 0.2;
    if (alternatives.length == 5) score += 0.1;
    if (alternatives.every(
      (a) => a.plainText.isNotEmpty || a.imageAssetId != null,
    )) {
      score += 0.1;
    }
    return score.clamp(0.0, 1.0);
  }
}

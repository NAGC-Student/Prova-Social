import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import 'question_parser.dart';

/// Crops answer choices that are drawn in the source PDF instead of encoded in
/// its text layer. The image remains the answer choice; this never guesses a
/// LaTeX or OCR transcription.
class VisualOptionImageExtractor {
  const VisualOptionImageExtractor();

  Future<Map<String, Uint8List>> extract(
    Uint8List pdfBytes,
    List<ImportedQuestion> questions, {
    int maxLongEdge = 1800,
    int maxTotalBytes = 4 * 1024 * 1024,
  }) async {
    final candidates = questions
        .where(
          (question) =>
              question.hasVisualOptions &&
              question.number != null &&
              question.sourcePages.isNotEmpty &&
              question.options.any((option) => option.trim().isEmpty),
        )
        .toList(growable: false);
    if (candidates.isEmpty) return const {};
    if (maxLongEdge < 640 || maxLongEdge > 3000) {
      throw RangeError.range(maxLongEdge, 640, 3000, 'maxLongEdge');
    }
    if (maxTotalBytes < 1024 || maxTotalBytes > 16 * 1024 * 1024) {
      throw RangeError.range(
        maxTotalBytes,
        1024,
        16 * 1024 * 1024,
        'maxTotalBytes',
      );
    }

    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      pdfBytes,
      sourceName: 'visual-options.pdf',
    );
    try {
      final result = <String, Uint8List>{};
      var totalBytes = 0;
      final questionsByPage = <int, List<ImportedQuestion>>{};
      for (final question in candidates) {
        for (final page in question.sourcePages) {
          questionsByPage.putIfAbsent(page, () => []).add(question);
        }
      }

      for (final entry in questionsByPage.entries) {
        final pageIndex = entry.key - 1;
        if (pageIndex < 0 || pageIndex >= document.pages.length) continue;
        final page = document.pages[pageIndex];
        final text = await page.loadStructuredText();
        final lines = _lines(text.fragments, pageWidth: page.width);
        final crops = <({ImportedQuestion question, int option, _Crop crop})>[];
        for (final question in entry.value) {
          final markers = _markersForQuestion(
            lines,
            question.number!,
            pageWidth: page.width,
          );
          if (markers.length != question.options.length) continue;
          final rowHeights = [
            for (var index = 0; index < markers.length - 1; index++)
              (markers[index].centerY - markers[index + 1].centerY).abs(),
          ]..sort();
          final fallbackHeight = rowHeights.isEmpty
              ? markers.first.height * 2.2
              : rowHeights[rowHeights.length ~/ 2];
          final markerLines = lines
              .where((line) => _optionLetter(line.text) != null)
              .toList(growable: false);
          final twoMarkerColumns =
              markerLines
                      .where((line) => line.centerX < page.width / 2)
                      .length >=
                  4 &&
              markerLines
                      .where((line) => line.centerX >= page.width / 2)
                      .length >=
                  4;
          final twoColumns =
              _hasTwoColumns(lines, page.width) || twoMarkerColumns;
          for (var index = 0; index < markers.length; index++) {
            if (question.options[index].trim().isNotEmpty) continue;
            final marker = markers[index];
            final nextMarkerY = index + 1 < markers.length
                ? markers[index + 1].top
                : marker.centerY - fallbackHeight;
            final topPoint = page.height - marker.top;
            final startY = math.max(0.0, topPoint - 1.5);
            final endY = math.min(
              page.height,
              math.max(startY + marker.height, page.height - nextMarkerY - 1),
            );
            final leftPoint = math.max(0.0, marker.right + 1.5);
            final rightPoint = twoColumns && marker.centerX < page.width / 2
                ? page.width / 2 - 10
                : page.width - 24;
            if (rightPoint - leftPoint < 24 || endY - startY < 8) continue;
            crops.add((
              question: question,
              option: index,
              crop: _Crop(
                left: leftPoint,
                top: startY,
                right: rightPoint,
                bottom: endY,
              ),
            ));
          }
        }
        if (crops.isEmpty) continue;

        final scale = math
            .min(maxLongEdge / math.max(page.width, page.height), 2.4)
            .toDouble();
        PdfImage? rendered;
        try {
          rendered = await page.render(
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
            backgroundColor: 0xffffffff,
          );
          if (rendered == null) continue;
          final bitmap = img.Image.fromBytes(
            width: rendered.width,
            height: rendered.height,
            bytes: rendered.pixels.buffer,
            order: img.ChannelOrder.bgra,
          );
          for (final entry in crops) {
            final x = (entry.crop.left * scale).floor().clamp(
              0,
              rendered.width - 1,
            );
            final y = (entry.crop.top * scale).floor().clamp(
              0,
              rendered.height - 1,
            );
            final right = (entry.crop.right * scale).ceil().clamp(
              x + 1,
              rendered.width,
            );
            final bottom = (entry.crop.bottom * scale).ceil().clamp(
              y + 1,
              rendered.height,
            );
            final crop = img.copyCrop(
              bitmap,
              x: x,
              y: y,
              width: right - x,
              height: bottom - y,
            );
            final jpeg = Uint8List.fromList(img.encodeJpg(crop, quality: 90));
            if (totalBytes + jpeg.length > maxTotalBytes) return result;
            result['${entry.question.id}:${entry.option}'] = jpeg;
            totalBytes += jpeg.length;
          }
        } finally {
          rendered?.dispose();
        }
      }
      return Map.unmodifiable(result);
    } finally {
      await document.dispose();
    }
  }

  List<_TextLine> _lines(
    List<PdfPageTextFragment> fragments, {
    required double pageWidth,
  }) {
    final lines = <_TextLine>[];
    for (final fragment in fragments) {
      if (fragment.text.trim().isEmpty) continue;
      final centerY = (fragment.bounds.top + fragment.bounds.bottom) / 2;
      final height = (fragment.bounds.top - fragment.bounds.bottom).abs();
      _TextLine? match;
      for (final line in lines.reversed) {
        final tolerance = math.max(line.height, height) * .55;
        final gap = fragment.bounds.left > line.right
            ? fragment.bounds.left - line.right
            : line.left > fragment.bounds.right
            ? line.left - fragment.bounds.right
            : 0.0;
        if ((line.centerY - centerY).abs() <= tolerance &&
            gap <= pageWidth * .015) {
          match = line;
          break;
        }
      }
      if (match == null) {
        lines.add(_TextLine(fragment));
      } else {
        match.fragments.add(fragment);
      }
    }
    for (final line in lines) {
      line.fragments.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    }
    return lines;
  }

  List<_TextLine> _markersForQuestion(
    List<_TextLine> lines,
    int questionNumber, {
    required double pageWidth,
  }) {
    final questionAnchors = lines
        .where((line) => _questionNumber(line.text) == questionNumber)
        .toList(growable: false);
    final allMarkers = lines
        .where((line) => _optionLetter(line.text) != null)
        .toList(growable: false);
    final anchorCandidates = <({_TextLine anchor, List<_TextLine> markers})>[];
    for (final anchor in questionAnchors) {
      final nextAnchorY = questionAnchors
          .where(
            (other) =>
                (other.centerX - anchor.centerX).abs() < pageWidth * .06 &&
                other.centerY < anchor.centerY,
          )
          .map((other) => other.centerY)
          .fold<double?>(null, (closest, y) {
            if (closest == null || y > closest) return y;
            return closest;
          });
      final markers =
          allMarkers
              .where(
                (line) =>
                    (line.centerX - anchor.centerX).abs() < pageWidth * .06 &&
                    line.centerY < anchor.centerY &&
                    (nextAnchorY == null || line.centerY > nextAnchorY),
              )
              .toList()
            ..sort((a, b) => b.centerY.compareTo(a.centerY));
      anchorCandidates.add((anchor: anchor, markers: markers));
    }
    anchorCandidates.sort(
      (a, b) => b.markers.length.compareTo(a.markers.length),
    );
    for (final candidate in anchorCandidates) {
      if (candidate.markers.length < 4) continue;
      final ordered = <_TextLine>[];
      for (final line in candidate.markers) {
        final letter = _optionLetter(line.text);
        final expected = String.fromCharCode(65 + ordered.length);
        if (letter == expected) {
          ordered.add(line);
        } else if (letter != null && ordered.isNotEmpty) {
          break;
        }
      }
      if (ordered.length == 5) return ordered;
    }

    // Some two-column PDFs place a question's five image choices at the top
    // of the next page, before the next numbered question in the other column.
    // Accept that continuation only when there is exactly one unanchored A–E
    // marker group on this page; ambiguous pages stay on the full-page preview.
    final anchoredColumns = lines
        .where((line) => _questionNumber(line.text) != null)
        .map((line) => line.centerX)
        .toList(growable: false);
    final orphanGroups = <List<_TextLine>>[];
    for (final isLeftColumn in [true, false]) {
      final columnMarkers =
          allMarkers
              .where(
                (line) =>
                    (line.centerX < pageWidth / 2) == isLeftColumn &&
                    !anchoredColumns.any(
                      (x) => (x - line.centerX).abs() < pageWidth * .06,
                    ),
              )
              .toList()
            ..sort((a, b) => b.centerY.compareTo(a.centerY));
      final group = <_TextLine>[];
      for (final line in columnMarkers) {
        final letter = _optionLetter(line.text);
        final expected = String.fromCharCode(65 + group.length);
        if (letter == expected) {
          group.add(line);
        } else if (letter == 'A') {
          if (group.length == 5) orphanGroups.add(List.of(group));
          group
            ..clear()
            ..add(line);
        } else {
          if (group.length == 5) orphanGroups.add(List.of(group));
          group.clear();
        }
      }
      if (group.length == 5) orphanGroups.add(List.of(group));
    }
    if (orphanGroups.length == 1) return orphanGroups.single;
    return const [];
  }

  int? _questionNumber(String text) {
    final match = RegExp(
      r'^\s*(?:quest[aã]o\s*)?0*(\d{1,3})[.):-]?\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String? _optionLetter(String text) => RegExp(
    r'^\s*\(?([A-E])\)?(?:\s*\(\))?\s*[.)-]?\s*$',
    caseSensitive: false,
  ).firstMatch(text)?.group(1)?.toUpperCase();

  bool _hasTwoColumns(List<_TextLine> lines, double pageWidth) =>
      lines.where((line) => line.centerX < pageWidth * .42).length >= 4 &&
      lines.where((line) => line.centerX > pageWidth * .58).length >= 4;
}

class _TextLine {
  _TextLine(PdfPageTextFragment fragment) : fragments = [fragment];

  final List<PdfPageTextFragment> fragments;
  String get text =>
      fragments.map((fragment) => fragment.text.trim()).join(' ');
  double get centerY =>
      fragments
          .map((fragment) => (fragment.bounds.top + fragment.bounds.bottom) / 2)
          .reduce((a, b) => a + b) /
      fragments.length;
  double get centerX => (left + right) / 2;
  double get height => fragments
      .map((fragment) => (fragment.bounds.top - fragment.bounds.bottom).abs())
      .reduce(math.max);
  double get top =>
      fragments.map((fragment) => fragment.bounds.top).reduce(math.max);
  double get bottom =>
      fragments.map((fragment) => fragment.bounds.bottom).reduce(math.min);
  double get left =>
      fragments.map((fragment) => fragment.bounds.left).reduce(math.min);
  double get right =>
      fragments.map((fragment) => fragment.bounds.right).reduce(math.max);
}

class _Crop {
  const _Crop({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

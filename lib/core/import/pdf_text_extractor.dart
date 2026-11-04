import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:pdfrx/pdfrx.dart';

import 'page_furniture_filter.dart';
import 'ocr_service.dart';
import 'ocr_layout_orderer.dart';
import 'ocr_router.dart';
import 'ocr_recognition.dart';
import 'text_normalizer.dart';

enum PdfPageTextSource { nativeText, onDeviceOcr, none }

class PdfPageExtraction {
  const PdfPageExtraction({
    required this.pageNumber,
    required this.nativeText,
    required this.text,
    required this.source,
    required this.ocrAttempted,
    required this.route,
    required this.routeReason,
    this.engineUsed,
    this.confidence,
    this.regions = const [],
    this.footerLines = const <int>{},
    this.warning,
  });

  final int pageNumber;
  final String nativeText;
  final String text;
  final PdfPageTextSource source;
  final bool ocrAttempted;
  final OcrRoute route;
  final String routeReason;
  final OcrEngine? engineUsed;
  final double? confidence;
  final List<OcrTextRegion> regions;

  /// Indexes of the lines that sit in the bottom band of the sheet, where a
  /// page number or a column footer is printed.
  final Set<int> footerLines;

  final String? warning;

  bool get hasText => text.trim().isNotEmpty;

  bool get hasUsableText =>
      text.trim().length >= PdfTextExtractor.minimumNativeTextLength;

  PdfPageExtraction withText(String cleaned, {String? warning}) =>
      PdfPageExtraction(
        pageNumber: pageNumber,
        nativeText: nativeText,
        text: cleaned,
        source: source,
        ocrAttempted: ocrAttempted,
        route: route,
        routeReason: routeReason,
        engineUsed: engineUsed,
        confidence: confidence,
        regions: regions,
        footerLines: footerLines,
        warning: warning ?? this.warning,
      );
}

class PdfExtractionResult {
  const PdfExtractionResult({
    required this.pages,
    required this.ocrAvailable,
    this.furnitureLines = const [],
  });

  final List<PdfPageExtraction> pages;
  final bool ocrAvailable;

  /// Running headers, footers and page numbers that were dropped before the
  /// parser saw the text.
  final List<String> furnitureLines;

  int get pageCount => pages.length;

  /// Pages with a usable native text layer. OCR results are counted separately.
  int get pagesWithText => pages
      .where(
        (page) =>
            page.source == PdfPageTextSource.nativeText &&
            page.text.trim().length >= PdfTextExtractor.minimumNativeTextLength,
      )
      .length;

  int get ocrPages => pages
      .where(
        (page) => page.source == PdfPageTextSource.onDeviceOcr && page.hasText,
      )
      .length;

  int get paddleOcrPages =>
      pages.where((page) => page.engineUsed == OcrEngine.paddleOcr).length;

  int get mlKitPages =>
      pages.where((page) => page.engineUsed == OcrEngine.mlKit).length;

  int get unreadablePages => pages.where((page) => !page.hasUsableText).length;

  int get pagesWithWarnings =>
      pages.where((page) => page.warning != null).length;

  String get text => pages
      .where((page) => page.hasText)
      .map((page) => page.text.trim())
      .join('\n\n');

  bool get looksScanned =>
      pageCount > 0 &&
      pagesWithText < (pageCount * .25).ceil() &&
      ocrPages == 0;
}

class PdfPageLimitException implements Exception {
  const PdfPageLimitException({required this.pageCount, required this.limit});

  final int pageCount;
  final int limit;

  @override
  String toString() =>
      'O PDF tem $pageCount páginas; o limite é $limit. '
      'Divida o arquivo em PDFs menores e tente novamente.';
}

class PdfTextExtractor {
  const PdfTextExtractor({
    this.router = const OcrRouter(),
    this.layoutOrderer = const OcrLayoutOrderer(),
  });

  static const minimumNativeTextLength = OcrRouter.minimumNativeTextLength;
  static const defaultMaxPages = 500;

  /// Fraction of the sheet height, measured from its bottom edge, where a page
  /// number or the footer of a column sits.
  static const footerBand = .14;
  static Future<void>? _pdfrxInitialization;
  final OcrRouter router;
  final OcrLayoutOrderer layoutOrderer;

  static Future<void> initialize() => _initializePdfrx();

  static Future<void> _initializePdfrx() async {
    final existing = _pdfrxInitialization;
    if (existing != null) return existing;
    final initialization = pdfrxFlutterInitialize();
    _pdfrxInitialization = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_pdfrxInitialization, initialization)) {
        _pdfrxInitialization = null;
      }
      rethrow;
    }
  }

  Future<PdfExtractionResult> extract(
    Uint8List bytes, {
    String? sourceName,
    int maxPages = defaultMaxPages,
  }) async {
    if (maxPages < 1) {
      throw ArgumentError.value(maxPages, 'maxPages', 'Must be positive.');
    }
    await _initializePdfrx();
    final ocr = OcrService();
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(
        bytes,
        sourceName: sourceName ?? 'import.pdf',
      );
      if (document.pages.length > maxPages) {
        throw PdfPageLimitException(
          pageCount: document.pages.length,
          limit: maxPages,
        );
      }
      final pageResults = <PdfPageExtraction>[];
      for (final page in document.pages) {
        final structuredText = await page.loadStructuredText();
        final native = _nativeTextInReadingOrder(
          structuredText,
          pageWidth: page.width,
          pageHeight: page.height,
        );
        final nativeText = native.text;
        final decision = router.decide(
          nativeText: nativeText,
          availableEngines: ocr.availableEngines,
        );
        if (decision.route == OcrRoute.nativeText) {
          pageResults.add(
            PdfPageExtraction(
              pageNumber: page.pageNumber,
              nativeText: nativeText,
              text: nativeText,
              source: PdfPageTextSource.nativeText,
              ocrAttempted: false,
              route: decision.route,
              routeReason: decision.reason,
              footerLines: native.footerLines,
            ),
          );
          continue;
        }

        if (decision.route == OcrRoute.unavailable) {
          pageResults.add(
            PdfPageExtraction(
              pageNumber: page.pageNumber,
              nativeText: nativeText,
              text: nativeText,
              source: nativeText.isEmpty
                  ? PdfPageTextSource.none
                  : PdfPageTextSource.nativeText,
              ocrAttempted: false,
              route: decision.route,
              routeReason: decision.reason,
              footerLines: native.footerLines,
              warning: decision.reason,
            ),
          );
          continue;
        }

        OcrRecognition? recognized;
        var engineFailed = false;
        for (final engine in decision.enginesToTry) {
          try {
            final attempt = await ocr.recognizePage(page, engine: engine);
            if (attempt.text.trim().length >=
                OcrRouter.minimumNativeTextLength) {
              recognized = attempt;
              break;
            }
          } catch (error, stackTrace) {
            debugPrint('[OCR] engine=$engine FALHOU: $error');
            debugPrint('$stackTrace');

            // A failed engine stays local to this page; try the next route.
            engineFailed = true;
          }
        }

        final recognizedText = recognized == null
            ? ''
            : recognized.regions.isEmpty
            ? recognized.text.trim()
            : layoutOrderer.text(recognized.regions).trim();
        final hasRecognizedText =
            recognizedText.length >= OcrRouter.minimumNativeTextLength;
        pageResults.add(
          PdfPageExtraction(
            pageNumber: page.pageNumber,
            nativeText: nativeText,
            text: hasRecognizedText ? recognizedText : nativeText,
            source: hasRecognizedText
                ? PdfPageTextSource.onDeviceOcr
                : nativeText.isEmpty
                ? PdfPageTextSource.none
                : PdfPageTextSource.nativeText,
            ocrAttempted: decision.enginesToTry.isNotEmpty,
            route: decision.route,
            routeReason: decision.reason,
            engineUsed: recognized?.engine,
            confidence: recognized?.confidence,
            regions: recognized?.regions ?? const [],
            // The footer coordinates belong to the text layer: an OCR page has
            // its own lines and falls back to the position-based edge rule.
            footerLines: hasRecognizedText ? const <int>{} : native.footerLines,
            warning: hasRecognizedText
                ? null
                : engineFailed
                ? 'Não foi possível aplicar os motores OCR nesta página.'
                : 'OCR não encontrou texto suficiente nesta página.',
          ),
        );
      }
      final cleaned = _cleanExtractedPages(pageResults);
      return PdfExtractionResult(
        pages: cleaned.pages,
        ocrAvailable: ocr.availableEngines.isNotEmpty,
        furnitureLines: cleaned.furnitureLines,
      );
    } finally {
      try {
        await document?.dispose();
      } finally {
        await ocr.dispose();
      }
    }
  }

  /// Removes the running furniture and then normalizes the characters.
  ///
  /// A line is only proven to be a header once it keeps returning to the edge
  /// of page after page, so that evidence has to be gathered while the column
  /// wrapping is still visible: unwrapping first would glue a header to the
  /// sentence above it and hide the repetition.
  ({List<PdfPageExtraction> pages, List<String> furnitureLines})
  _cleanExtractedPages(List<PdfPageExtraction> pageResults) {
    final furniture = PageFurnitureFilter().apply(
      pageResults.map((page) => page.text),
      footers: pageResults.map((page) => page.footerLines).toList(),
    );
    final pages = <PdfPageExtraction>[
      for (var index = 0; index < pageResults.length; index++)
        pageResults[index].withText(
          ExamTextNormalizer.normalize(furniture.pages[index]),
        ),
    ];
    return (
      pages: List.unmodifiable(pages),
      furnitureLines: furniture.removedLines,
    );
  }

  /// Renders only requested source pages for image based question review.
  /// JPEG is used for compact previews; the original PDF remains the source
  /// of truth and raster rendering avoids destructive SVG conversion.
  Future<Map<int, Uint8List>> renderPages(
    Uint8List bytes,
    Iterable<int> pageNumbers, {
    int maxLongEdge = 1200,
    int jpegQuality = 76,
    int maxTotalBytes = 12 * 1024 * 1024,
    int maxPages = defaultMaxPages,
  }) async {
    final requested = pageNumbers.where((page) => page > 0).toSet();
    if (requested.isEmpty) return const {};
    if (maxPages < 1) {
      throw ArgumentError.value(maxPages, 'maxPages', 'Must be positive.');
    }
    if (maxLongEdge < 320 || maxLongEdge > 2400) {
      throw RangeError.range(maxLongEdge, 320, 2400, 'maxLongEdge');
    }
    if (maxTotalBytes < 1024 || maxTotalBytes > 64 * 1024 * 1024) {
      throw RangeError.range(
        maxTotalBytes,
        1024,
        64 * 1024 * 1024,
        'maxTotalBytes',
      );
    }
    await _initializePdfrx();
    final document = await PdfDocument.openData(
      bytes,
      sourceName: 'preview.pdf',
    );
    try {
      if (document.pages.length > maxPages) {
        throw PdfPageLimitException(
          pageCount: document.pages.length,
          limit: maxPages,
        );
      }
      final previews = <int, Uint8List>{};
      var totalBytes = 0;
      for (final page in document.pages) {
        if (!requested.contains(page.pageNumber)) continue;
        final scale = math
            .min(1.8, maxLongEdge / math.max(page.width, page.height))
            .toDouble();
        PdfImage? rendered;
        try {
          rendered = await page.render(
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
            backgroundColor: 0xffffffff,
          );
          if (rendered == null) continue;
          final encoded = await compute(_encodeRenderedPage, (
            pixels: rendered.pixels,
            width: rendered.width,
            height: rendered.height,
            quality: jpegQuality.clamp(50, 92).toInt(),
          ));
          if (totalBytes + encoded.length > maxTotalBytes) {
            debugPrint(
              '[PDF_PREVIEW] limite total atingido; demais páginas adiadas',
            );
            break;
          }
          previews[page.pageNumber] = encoded;
          totalBytes += encoded.length;
        } catch (error) {
          debugPrint(
            '[PDF_PREVIEW] page=${page.pageNumber} falhou: ${error.runtimeType}',
          );
        } finally {
          rendered?.dispose();
        }
      }
      return Map.unmodifiable(previews);
    } finally {
      await document.dispose();
    }
  }

  ({String text, Set<int> footerLines}) _nativeTextInReadingOrder(
    PdfPageText pageText, {
    required double pageWidth,
    required double pageHeight,
  }) {
    if (pageText.fragments.isEmpty) {
      return (text: pageText.fullText, footerLines: const <int>{});
    }

    final lines = <_NativeTextLine>[];
    for (final fragment in pageText.fragments) {
      if (fragment.text.trim().isEmpty) continue;
      final lineY = (fragment.bounds.top + fragment.bounds.bottom) / 2;
      final fragmentHeight = (fragment.bounds.top - fragment.bounds.bottom)
          .abs();
      _NativeTextLine? matchingLine;
      for (final line in lines.reversed) {
        final tolerance = math.max(line.height, fragmentHeight) * .55;
        final horizontalGap = fragment.bounds.left > line.right
            ? fragment.bounds.left - line.right
            : line.left > fragment.bounds.right
            ? line.left - fragment.bounds.right
            : 0.0;
        if ((line.centerY - lineY).abs() <= tolerance &&
            horizontalGap <= pageWidth * .015) {
          matchingLine = line;
          break;
        }
      }
      if (matchingLine == null) {
        lines.add(_NativeTextLine(fragment));
      } else {
        matchingLine.add(fragment);
      }
    }

    for (final line in lines) {
      line.sortFragments();
    }
    final columnLines = lines
        .where((line) => line.width < pageWidth * .58)
        .toList(growable: false);
    final splitX = _findNativeColumnSplit(columnLines, pageWidth);
    if (splitX == null) {
      final singleColumn = [...lines]
        ..sort((a, b) => b.centerY.compareTo(a.centerY));
      return _joinReadingBlocks([singleColumn], pageHeight: pageHeight);
    }

    final left = columnLines.where((line) => line.centerX < splitX).toList()
      ..sort((a, b) => b.centerY.compareTo(a.centerY));
    final right = columnLines.where((line) => line.centerX >= splitX).toList()
      ..sort((a, b) => b.centerY.compareTo(a.centerY));
    final spanning =
        lines.where((line) => line.width >= pageWidth * .58).toList()
          ..sort((a, b) => b.centerY.compareTo(a.centerY));

    final bodyMidpoint = columnLines.isEmpty
        ? 0.0
        : (columnLines.map((line) => line.centerY).reduce(math.max) +
                  columnLines.map((line) => line.centerY).reduce(math.min)) /
              2;
    final topSpanning = spanning
        .where((line) => line.centerY >= bodyMidpoint)
        .toList(growable: false);
    final bottomSpanning = spanning
        .where((line) => line.centerY < bodyMidpoint)
        .toList(growable: false);
    return _joinReadingBlocks([
      topSpanning,
      left,
      right,
      bottomSpanning,
    ], pageHeight: pageHeight);
  }

  /// Flattens the column blocks into one page text and reports which lines sit
  /// in the bottom band of the sheet. A footer is furniture wherever a column
  /// ends, and only the geometry knows that the tail of the left column is a
  /// page number rather than the end of a sentence.
  ({String text, Set<int> footerLines}) _joinReadingBlocks(
    List<List<_NativeTextLine>> blocks, {
    required double pageHeight,
  }) {
    final lines = <String>[];
    final footerLines = <int>{};
    final foot = pageHeight * footerBand;
    for (final block in blocks) {
      if (block.isEmpty) continue;
      if (lines.isNotEmpty) lines.add('');
      for (final line in block) {
        if (line.centerY <= foot) footerLines.add(lines.length);
        lines.add(line.text);
      }
    }
    return (text: lines.join('\n'), footerLines: Set.unmodifiable(footerLines));
  }

  double? _findNativeColumnSplit(
    List<_NativeTextLine> lines,
    double pageWidth,
  ) {
    if (lines.length < 10) return null;
    final centers = lines.map((line) => line.centerX).toList()..sort();
    final leftColumnLines = centers.where((x) => x < pageWidth * .42).length;
    final rightColumnLines = centers.where((x) => x > pageWidth * .58).length;
    if (leftColumnLines >= 4 && rightColumnLines >= 4) {
      return pageWidth / 2;
    }

    var largestGap = 0.0;
    var splitIndex = -1;
    for (var index = 1; index < centers.length; index++) {
      final gap = centers[index] - centers[index - 1];
      if (gap > largestGap) {
        largestGap = gap;
        splitIndex = index;
      }
    }
    if (splitIndex < 4 || centers.length - splitIndex < 4) return null;
    final splitX = (centers[splitIndex - 1] + centers[splitIndex]) / 2;
    if (largestGap < pageWidth * .12 ||
        splitX < pageWidth * .25 ||
        splitX > pageWidth * .75) {
      return null;
    }
    return splitX;
  }
}

Uint8List _encodeRenderedPage(
  ({Uint8List pixels, int width, int height, int quality}) page,
) {
  final bitmap = img.Image.fromBytes(
    width: page.width,
    height: page.height,
    bytes: page.pixels.buffer,
    order: img.ChannelOrder.bgra,
  );
  return img.encodeJpg(bitmap, quality: page.quality);
}

class _NativeTextLine {
  _NativeTextLine(PdfPageTextFragment fragment) : _fragments = [fragment];

  final List<PdfPageTextFragment> _fragments;

  void add(PdfPageTextFragment fragment) => _fragments.add(fragment);

  void sortFragments() =>
      _fragments.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

  String get text =>
      _fragments.map((fragment) => fragment.text.trim()).join(' ');

  double get centerY =>
      _fragments
          .map((fragment) => (fragment.bounds.top + fragment.bounds.bottom) / 2)
          .reduce((a, b) => a + b) /
      _fragments.length;

  double get height => _fragments
      .map((fragment) => (fragment.bounds.top - fragment.bounds.bottom).abs())
      .reduce(math.max);

  double get centerX => (left + right) / 2;

  double get left =>
      _fragments.map((fragment) => fragment.bounds.left).reduce(math.min);

  double get right =>
      _fragments.map((fragment) => fragment.bounds.right).reduce(math.max);

  double get width => right - left;
}

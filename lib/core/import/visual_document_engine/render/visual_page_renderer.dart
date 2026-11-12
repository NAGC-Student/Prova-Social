import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../models/visual_models.dart';

/// Renderiza páginas do PDF em imagens de alta resolução, preservando
/// coordenadas dos elementos originais (texto, imagens, vetores).
class VisualPageRenderer {
  const VisualPageRenderer();

  Future<List<VisualPage>> renderPages(
    Uint8List pdfBytes, {
    Iterable<int> pageNumbers = const [],
    int maxLongEdge = 1600,
    int jpegQuality = 82,
  }) async {
    if (maxLongEdge < 320 || maxLongEdge > 2400) {
      throw RangeError.range(maxLongEdge, 320, 2400, 'maxLongEdge');
    }
    if (jpegQuality < 50 || jpegQuality > 95) {
      throw RangeError.range(jpegQuality, 50, 95, 'jpegQuality');
    }

    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      pdfBytes,
      sourceName: 'visual-document.pdf',
    );
    try {
      final requested = pageNumbers.isEmpty
          ? List.generate(document.pages.length, (i) => i + 1)
          : pageNumbers
                .where((p) => p >= 1 && p <= document.pages.length)
                .toList();
      final pages = <VisualPage>[];
      for (final pageNumber in requested) {
        final page = document.pages[pageNumber - 1];
        final scale = math
            .min(2.0, maxLongEdge / math.max(page.width, page.height))
            .toDouble();
        PdfImage? rendered;
        try {
          rendered = await page.render(
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
            backgroundColor: 0xffffffff,
          );
          if (rendered == null) continue;
          final jpeg = await compute(_encodeRenderedPage, (
            pixels: rendered.pixels,
            width: rendered.width,
            height: rendered.height,
            quality: jpegQuality.clamp(50, 95).toInt(),
          ));
          final structuredText = await page.loadStructuredText();
          final elements = _elementsFromStructuredText(
            structuredText,
            pageWidth: page.width,
            pageHeight: page.height,
            scale: scale,
            renderedWidth: rendered.width.toDouble(),
            renderedHeight: rendered.height.toDouble(),
          );
          pages.add(
            VisualPage(
              number: pageNumber,
              width: page.width,
              height: page.height,
              imageBytes: jpeg,
              elements: elements,
              nativeText: structuredText.fullText,
            ),
          );
        } finally {
          rendered?.dispose();
        }
      }
      return pages;
    } finally {
      await document.dispose();
    }
  }

  List<VisualBlock> _elementsFromStructuredText(
    PdfPageText structuredText, {
    required double pageWidth,
    required double pageHeight,
    required double scale,
    required double renderedWidth,
    required double renderedHeight,
  }) {
    final elements = <VisualBlock>[];
    final sx = renderedWidth / pageWidth;
    final sy = renderedHeight / pageHeight;
    for (final fragment in structuredText.fragments) {
      if (fragment.text.trim().isEmpty) continue;
      final bounds = VisualRect(
        left: fragment.bounds.left * sx,
        top: fragment.bounds.top * sy,
        right: fragment.bounds.right * sx,
        bottom: fragment.bounds.bottom * sy,
      );
      elements.add(
        VisualBlock(
          type: VisualBlockType.text,
          bounds: bounds,
          text: fragment.text.trim(),
          confidence: 1.0,
        ),
      );
    }
    return List.unmodifiable(elements);
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

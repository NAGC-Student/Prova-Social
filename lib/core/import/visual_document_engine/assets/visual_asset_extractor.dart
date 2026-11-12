import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/visual_models.dart';

/// Extrai ativos visuais de uma página renderizada, cortando a região
/// correspondente. Os ativos são salvos como imagens independentes.
class VisualAssetExtractor {
  const VisualAssetExtractor();

  Future<Map<String, VisualAsset>> extractAssets(
    VisualPage page, {
    int maxLongEdge = 1800,
    int jpegQuality = 88,
  }) async {
    final assets = <String, VisualAsset>{};
    for (final block in page.elements) {
      if (block.type == VisualBlockType.text && block.assetId == null) continue;
      if (block.bounds.width < 8 || block.bounds.height < 8) continue;

      final assetId = block.assetId ?? _assetIdFromBlock(page.number, block);
      if (assets.containsKey(assetId)) continue;

      final bytes = await _cropRegion(
        page.imageBytes,
        page.width,
        page.height,
        block.bounds,
        maxLongEdge: maxLongEdge,
        jpegQuality: jpegQuality,
      );
      if (bytes.isEmpty) continue;

      final digest = sha256.convert(bytes).toString();
      final finalId = assetId.isEmpty || assetId.startsWith('asset-')
          ? 'asset-${digest.substring(0, 16)}'
          : assetId;
      assets[finalId] = VisualAsset(
        id: finalId,
        type: _assetType(block),
        bytes: bytes,
        mimeType: 'image/jpeg',
        sourcePage: page.number,
        bounds: block.bounds,
        sha256: digest,
      );
    }
    return Map.unmodifiable(assets);
  }

  Future<Uint8List> _cropRegion(
    Uint8List pageImage,
    double pageWidth,
    double pageHeight,
    VisualRect bounds, {
    int maxLongEdge = 1800,
    int jpegQuality = 88,
  }) async {
    final bitmap = img.decodeImage(pageImage);
    if (bitmap == null) return Uint8List(0);

    final sx = bitmap.width / pageWidth;
    final sy = bitmap.height / pageHeight;
    final x = (bounds.left * sx).floor().clamp(0, bitmap.width - 1);
    final y = (bounds.top * sy).floor().clamp(0, bitmap.height - 1);
    final right = (bounds.right * sx).ceil().clamp(x + 1, bitmap.width);
    final bottom = (bounds.bottom * sy).ceil().clamp(y + 1, bitmap.height);
    if (right - x < 4 || bottom - y < 4) return Uint8List(0);

    final crop = img.copyCrop(
      bitmap,
      x: x,
      y: y,
      width: right - x,
      height: bottom - y,
    );
    final resized = _fitLongEdge(crop, maxLongEdge);
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  }

  img.Image _fitLongEdge(img.Image image, int maxLongEdge) {
    final longEdge = image.width > image.height ? image.width : image.height;
    if (longEdge <= maxLongEdge) return image;
    final scale = maxLongEdge / longEdge;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  String _assetIdFromBlock(int pageNumber, VisualBlock block) {
    final source =
        '$pageNumber-${block.bounds.left.round()}-${block.bounds.top.round()}-${block.type.name}';
    return 'asset-${sha256.convert(utf8.encode(source)).toString().substring(0, 16)}';
  }

  VisualAssetType _assetType(VisualBlock block) {
    return switch (block.type) {
      VisualBlockType.formula => VisualAssetType.formula,
      VisualBlockType.image => VisualAssetType.figure,
      VisualBlockType.table => VisualAssetType.table,
      VisualBlockType.graphic => VisualAssetType.graphic,
      VisualBlockType.optionContent ||
      VisualBlockType.optionLabel => VisualAssetType.optionImage,
      _ => VisualAssetType.figure,
    };
  }
}

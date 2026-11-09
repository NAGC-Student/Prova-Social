import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/theme/app_theme.dart';

/// WCAG 2.x relative luminance for an sRGB color.
double relativeLuminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrastRatio(Color foreground, Color background) {
  final first = relativeLuminance(foreground);
  final second = relativeLuminance(background);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // AA exige 4,5 para texto normal e 3,0 para texto grande/componentes.
  // A folga mínima de 0,5 eleva os pisos para 5,0 e 3,5.
  const normalTextMinimum = 5.0;
  const largeTextOrComponentMinimum = 3.5;

  group('texto normal atinge AA com folga de 0,5', () {
    final pairs = <String, (Color, Color)>{
      'textPrimary sobre background': (
        EmeraldColors.textPrimary,
        EmeraldColors.background,
      ),
      'textSecondary sobre background': (
        EmeraldColors.textSecondary,
        EmeraldColors.background,
      ),
      'textMuted sobre background': (
        EmeraldColors.textMuted,
        EmeraldColors.background,
      ),
      'textPrimary sobre surface': (
        EmeraldColors.textPrimary,
        EmeraldColors.surface,
      ),
      'textSecondary sobre surface': (
        EmeraldColors.textSecondary,
        EmeraldColors.surface,
      ),
      'textMuted sobre surface': (
        EmeraldColors.textMuted,
        EmeraldColors.surface,
      ),
      'textPrimary sobre surfaceElevated': (
        EmeraldColors.textPrimary,
        EmeraldColors.surfaceElevated,
      ),
      'textSecondary sobre surfaceElevated': (
        EmeraldColors.textSecondary,
        EmeraldColors.surfaceElevated,
      ),
      'textMuted sobre surfaceElevated': (
        EmeraldColors.textMuted,
        EmeraldColors.surfaceElevated,
      ),
      'textPrimary sobre surfaceHighlight': (
        EmeraldColors.textPrimary,
        EmeraldColors.surfaceHighlight,
      ),
    };

    pairs.forEach((label, pair) {
      test(label, () {
        expect(
          contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(normalTextMinimum),
          reason: label,
        );
      });
    });
  });

  group('texto grande e componentes atingem AA com folga de 0,5', () {
    final pairs = <String, (Color, Color)>{
      'primary sobre background': (
        EmeraldColors.primary,
        EmeraldColors.background,
      ),
      'primary sobre surface': (EmeraldColors.primary, EmeraldColors.surface),
      'error sobre surface': (EmeraldColors.error, EmeraldColors.surface),
      'warning sobre surface': (EmeraldColors.warning, EmeraldColors.surface),
      'primaryLight sobre surfaceHighlight': (
        EmeraldColors.primaryLight,
        EmeraldColors.surfaceHighlight,
      ),
    };

    pairs.forEach((label, pair) {
      test(label, () {
        expect(
          contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(largeTextOrComponentMinimum),
          reason: label,
        );
      });
    });
  });

  test('textMuted ajustado permanece distinto dos outros textos', () {
    expect(EmeraldColors.textMuted, isNot(EmeraldColors.textSecondary));
    expect(EmeraldColors.textMuted, isNot(EmeraldColors.textPrimary));
  });
}

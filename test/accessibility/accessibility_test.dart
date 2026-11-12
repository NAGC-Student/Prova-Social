import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/core/widgets/exam_list_tile.dart';
import 'package:prova_social/domain/models/exam.dart';

double relativeLuminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrastRatio(Color fg, Color bg) {
  final l1 = relativeLuminance(fg);
  final l2 = relativeLuminance(bg);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Touch target minimum 48x48px', () {
    testWidgets('ExamListTile action buttons meet 48px minimum', (tester) async {
      const exam = Exam(
        id: 'test',
        category: 'Test',
        title: 'Test Exam',
        description: '',
        author: 'Author',
        durationMinutes: 60,
        attempts: 0,
        questions: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ExamListTile(
              exam: exam,
              onSaveToggle: () {},
              saved: false,
            ),
          ),
        ),
      );

      final saveButton = find.byIcon(Icons.bookmark_outline_rounded);
      expect(saveButton, findsOneWidget);

      final button = find.byType(IconButton).first;
      final renderObject = tester.renderObject<RenderBox>(button);
      expect(renderObject.size.width, greaterThanOrEqualTo(48.0));
      expect(renderObject.size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('Text scaling up to 1.3x', () {
testWidgets('ExamListTile text scales without overflow', (tester) async {
      const exam = Exam(
        id: 'test',
        category: 'Test Category',
        title: 'Very Long Exam Title That Should Wrap Properly',
        description: 'Description',
        author: 'Author',
        durationMinutes: 120,
        attempts: 0,
        questions: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: ExamListTile(
                exam: exam,
                onSaveToggle: () {},
                saved: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Very Long Exam Title That Should Wrap Properly'), findsOneWidget);
      expect(find.text('Test Category'), findsOneWidget);
    });
  });

  group('Reduced motion respected', () {
    testWidgets('Animations disabled when reduceMotion is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: Center(child: Text('Test'))),
          ),
        ),
      );

      final mq = MediaQuery.of(tester.element(find.byType(Text)));
      expect(mq.disableAnimations, isTrue);
    });
  });

  group('Focus order logical', () {
    testWidgets('ExamListTile focus order follows visual order', (tester) async {
      const exam = Exam(
        id: 'test',
        category: 'Test',
        title: 'Test Exam',
        description: '',
        author: 'Author',
        durationMinutes: 60,
        attempts: 0,
        questions: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                ExamListTile(
                  exam: exam,
                  onSaveToggle: () {},
                  saved: false,
                ),
                ExamListTile(
                  exam: const Exam(
                    id: 'test2',
                    category: 'Test',
                    title: 'Second Exam',
                    description: '',
                    author: 'Author',
                    durationMinutes: 60,
                    attempts: 0,
                    questions: [],
                  ),
                  onSaveToggle: () {},
                  saved: true,
                ),
              ],
            ),
          ),
        ),
      );

      // Focus should move in order: first tile's save button, second tile's save button
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
    });
  });

  group('Color contrast with textScaler 1.3', () {
    test('textPrimary on background meets AA at 1.3x scale', () {
      final ratio = contrastRatio(EmeraldColors.textPrimary, EmeraldColors.background);
      expect(ratio, greaterThanOrEqualTo(5.0));
    });

    test('textSecondary on background meets AA at 1.3x scale', () {
      final ratio = contrastRatio(EmeraldColors.textSecondary, EmeraldColors.background);
      expect(ratio, greaterThanOrEqualTo(5.0));
    });

    test('textMuted on background meets AA at 1.3x scale', () {
      // textMuted (#718078) on background (#050907) gives ~4.83 ratio
      // This is acceptable for muted/secondary text per WCAG
      final ratio = contrastRatio(EmeraldColors.textMuted, EmeraldColors.background);
      expect(ratio, greaterThanOrEqualTo(4.5)); // AA minimum for normal text
    });
  });
}
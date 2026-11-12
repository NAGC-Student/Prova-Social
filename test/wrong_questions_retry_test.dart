import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:prova_social/features/result/result_page.dart';

class _MemoryDraftStorage implements DraftStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _MemoryQueueStorage implements AttemptQueueStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  testWidgets('a single mistake offers the singular retry label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const exam = Exam(
      id: 'exam-singular',
      title: 'Prova curta',
      category: 'Geral',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: [
        Question(
          id: 'q0',
          topic: 'Geral',
          statement: 'Questão certa',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          id: 'q1',
          topic: 'Geral',
          statement: 'Questão errada',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: const {'q0': 0, 'q1': 1},
      markedForReview: const {},
      durationSeconds: 45,
      finishedAt: DateTime.utc(2026, 11, 1),
    );

    final draftStore = AttemptDraftStore(storage: _MemoryDraftStorage());
    addTearDown(draftStore.dispose);
    final syncService = AttemptSyncService(
      store: AttemptQueueStore(storage: _MemoryQueueStorage()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage(
          result: result,
          draftStore: draftStore,
          syncService: syncService,
        ),
      ),
    );
    expect(find.text('Refazer 1 questão errada'), findsOneWidget);
    expect(find.textContaining('Refazer 1 questões'), findsNothing);

    await tester.ensureVisible(find.text('Refazer 1 questão errada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refazer 1 questão errada'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizPage), findsOneWidget);
    expect(find.text('Questão 1 de 1'), findsOneWidget);
    expect(find.text('Questão errada'), findsOneWidget);
    expect(find.text('Questão certa'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:prova_social/features/result/result_page.dart';
import 'package:prova_social/features/result/review_page.dart';

void main() {
  testWidgets('result opens a virtualized review with working filters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final exam = Exam(
      id: 'exam',
      title: 'Prova longa',
      category: 'Geral',
      description: '',
      author: 'Fonte',
      durationMinutes: 60,
      attempts: 0,
      questions: [
        for (var index = 0; index < 100; index++)
          Question(
            id: 'question-$index',
            topic: 'Geral',
            statement: 'Enunciado $index',
            options: const ['A', 'B'],
            correctIndex: index == 3 ? null : 0,
          ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: {0: 0, 1: 1, 3: 1},
      markedForReview: const {},
      durationSeconds: 120,
      finishedAt: DateTime.utc(2026, 10, 31),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage(result: result, syncService: _testSyncService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('dos erros'), findsOneWidget);
    expect(find.text('Abrir revisão das questões'), findsOneWidget);
    expect(find.text('Enunciado 0'), findsNothing);

    await tester.ensureVisible(find.text('Abrir revisão das questões'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir revisão das questões'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewPage), findsOneWidget);
    expect(find.text('Enunciado 0'), findsOneWidget);
    expect(find.text('Enunciado 99'), findsNothing);

    await tester.tap(find.text('Erradas'));
    await tester.pumpAndSettle();
    expect(find.text('Questão 2 · Errada'), findsOneWidget);
    expect(find.text('Enunciado 0'), findsNothing);

    await tester.tap(find.text('Sem gabarito'));
    await tester.pumpAndSettle();
    expect(find.text('Questão 4 · Sem gabarito'), findsOneWidget);
    expect(find.text('Exibidas: 1'), findsOneWidget);
  });

  testWidgets('lets the user adjust filters when none of the errors match', (
    tester,
  ) async {
    final exam = Exam(
      id: 'exam-filter-empty',
      title: 'Prova com assuntos',
      category: 'Geral',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: const [
        Question(
          id: 'math',
          topic: 'Matemática',
          statement: 'Questão errada',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          id: 'language',
          topic: 'Português',
          statement: 'Questão certa',
          options: ['A', 'B'],
          correctIndex: 1,
        ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: const {0: 1, 1: 1},
      markedForReview: const {},
      durationSeconds: 30,
      finishedAt: DateTime.utc(2026, 10, 31),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage(result: result, syncService: _testSyncService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtros e quantidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos os assuntos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Português').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ainda não há questões respondidas incorretamente que atendam a esses filtros.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ajustar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar questões para revisar'), findsOneWidget);
  });

  testWidgets('retry opens a new attempt with only the wrong questions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final exam = Exam(
      id: 'exam-retry',
      title: 'Prova curta',
      category: 'Geral',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: const [
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
          statement: 'Questão errada um',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          id: 'q2',
          topic: 'Geral',
          statement: 'Questão errada dois',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          id: 'q3',
          topic: 'Geral',
          statement: 'Questão em branco',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: {0: 0, 1: 1, 2: 1},
      markedForReview: const {},
      durationSeconds: 90,
      finishedAt: DateTime.utc(2026, 10, 31),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage(
          result: result,
          syncService: _testSyncService(),
          draftStore: AttemptDraftStore(storage: _MemoryDraftStorage()),
        ),
      ),
    );
    const retryLabel = 'Refazer 2 questões erradas';
    expect(find.text(retryLabel), findsOneWidget);

    await tester.ensureVisible(find.text(retryLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(retryLabel));
    await tester.pump();
    for (var frame = 0; frame < 20; frame++) {
      if (find.text('Questão 1 de 2').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(QuizPage), findsOneWidget);
    expect(find.text('Questão 1 de 2'), findsOneWidget);
    expect(find.text('Questão errada um'), findsOneWidget);
    expect(find.text('Questão certa'), findsNothing);
    expect(find.text('Questão em branco'), findsNothing);
  });
}

AttemptSyncService _testSyncService() => AttemptSyncService(
  store: AttemptQueueStore(storage: _MemoryAttemptQueueStorage()),
);

class _MemoryAttemptQueueStorage implements AttemptQueueStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _MemoryDraftStorage implements DraftStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

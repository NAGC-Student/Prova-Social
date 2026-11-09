import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('Focus Mode fits a narrow phone with larger system text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AttemptDraftStore(storage: _MemoryDraftStorage());
    final syncService = AttemptSyncService(
      store: AttemptQueueStore(storage: _MemoryQueueStorage()),
    );
    const exam = Exam(
      id: 'small-phone',
      category: 'Geral',
      title: 'Prova',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: [
        Question(
          id: 'q1',
          topic: 'Geral',
          statement: 'Pergunta?',
          options: ['Alternativa um', 'Alternativa dois'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: QuizPage(
            exam: exam,
            draftStore: store,
            syncService: syncService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Questão 1 de 1'), findsOneWidget);
    expect(find.text('Revisar entrega'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}

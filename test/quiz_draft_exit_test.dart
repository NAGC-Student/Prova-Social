import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';

class SlowDraftStorage implements DraftStorage {
  final values = <String, String>{};
  final writes = <Completer<void>>[];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    final gate = Completer<void>();
    writes.add(gate);
    await gate.future;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _FailingDraftStorage implements DraftStorage {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {
    throw StateError('disco cheio');
  }

  @override
  Future<void> remove(String key) async {}
}

class _MemoryQueueStorage implements AttemptQueueStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  testWidgets('sair espera a gravação pendente e preserva a resposta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = SlowDraftStorage();
    final store = AttemptDraftStore(storage: storage);
    final syncService = AttemptSyncService(
      store: AttemptQueueStore(storage: _MemoryQueueStorage()),
    );
    const exam = Exam(
      id: 'exam',
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
          options: ['Um', 'Dois'],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuizPage(
                    exam: exam,
                    draftStore: store,
                    syncService: syncService,
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dois'));
    await tester.pump();
    expect(find.text('Salvando no aparelho'), findsOneWidget);
    await tester.tap(find.byTooltip('Sair da prova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pump();
    expect(find.byType(QuizPage), findsOneWidget);

    storage.writes[0].complete();
    await tester.pump();
    expect(find.byType(QuizPage), findsOneWidget);
    storage.writes[1].complete();
    await tester.pumpAndSettle();
    expect(find.byType(QuizPage), findsNothing);
    expect((await store.load('exam'))!.answers['q1'], 1);
    store.dispose();
  });

  testWidgets('falha ao salvar mantém a resposta e impede sair', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AttemptDraftStore(storage: _FailingDraftStorage());
    final syncService = AttemptSyncService(
      store: AttemptQueueStore(storage: _MemoryQueueStorage()),
    );
    const exam = Exam(
      id: 'exam-falha',
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
          options: ['Um', 'Dois'],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(exam: exam, draftStore: store, syncService: syncService),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Dois'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Falha ao salvar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.byTooltip('Sair da prova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizPage), findsOneWidget);
    expect(
      find.text(
        'Não foi possível salvar no aparelho. Tente novamente antes de sair.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    store.dispose();
  });
}

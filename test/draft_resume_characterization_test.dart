import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/core/backend/local_payload_store.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Caracterização do estado de 05a8fc1: o rascunho guarda índices posicionais e o
// clientAttemptId da tentativa anterior (attempt_draft_store.dart:7-28,
// quiz_page.dart:128-133). Registrar isso não é aprovar o comportamento.
const _par = Question(
  id: 'q-par',
  topic: 'Geral',
  statement: 'Questão par',
  options: ['A', 'B'],
  correctIndex: 1,
);
const _impar = Question(
  id: 'q-impar',
  topic: 'Geral',
  statement: 'Questão ímpar',
  options: ['A', 'B'],
  correctIndex: 0,
);

Exam _prova(List<Question> questions, {String id = 'exam'}) => Exam(
  id: id,
  category: 'Geral',
  title: 'Prova',
  description: '',
  author: 'Fonte',
  durationMinutes: 30,
  attempts: 0,
  questions: questions,
);

void main() {
  late _RascunhoMemoria storage;
  late AttemptDraftStore store;

  setUp(() {
    storage = _RascunhoMemoria();
    store = AttemptDraftStore(storage: storage);
  });
  tearDown(() => store.dispose());

  test('o rascunho não identifica questões, só posições', () async {
    final v1 = _prova([_par, _impar]);
    await store.save(
      v1.id,
      const AttemptDraft(
        answers: {0: 1, 1: 0},
        review: {},
        current: 0,
        elapsedSeconds: 12,
      ),
    );
    final retomado = (await store.load(v1.id))!;

    final resultadoV1 = ExamResult(
      exam: v1,
      answers: retomado.answers,
      markedForReview: retomado.review,
      durationSeconds: retomado.elapsedSeconds,
      finishedAt: DateTime.utc(2026, 11, 5),
    );
    // A mesma tentativa gravada, reaplicada sobre a versão reordenada da prova.
    final v2 = _prova([_impar, _par]);
    final resultadoV2 = ExamResult(
      exam: v2,
      answers: retomado.answers,
      markedForReview: retomado.review,
      durationSeconds: retomado.elapsedSeconds,
      finishedAt: resultadoV1.finishedAt,
    );

    expect(resultadoV1.correct, 2);
    expect(resultadoV2.correct, 0);
    expect(resultadoV2.wrongQuestionIndices, [0, 1]);
  });

  test('resposta além da nova versão some sem avisar', () async {
    final grande = _prova([_par, _impar, _par]);
    await store.save(
      grande.id,
      const AttemptDraft(
        answers: {0: 1, 1: 0, 2: 1},
        review: {2},
        current: 2,
        elapsedSeconds: 40,
      ),
    );
    final retomado = (await store.load(grande.id))!;
    expect(retomado.answers, hasLength(3));

    final pequena = _prova([_par], id: 'exam');
    final resultado = ExamResult(
      exam: pequena,
      answers: retomado.answers,
      markedForReview: retomado.review,
      durationSeconds: retomado.elapsedSeconds,
      finishedAt: DateTime.utc(2026, 11, 5),
    );

    expect(retomado.current, 2);
    expect(resultado.correct, 1);
    expect(resultado.unanswered, 0);
    expect(resultado.markedForReview, {2});
    expect(resultado.toJson()['total'], 1);
  });

  test('a retomada preserva o clientAttemptId da tentativa anterior', () async {
    final prova = _prova([_par, _impar]);
    await store.save(
      prova.id,
      const AttemptDraft(
        answers: {0: 1},
        review: {},
        current: 1,
        elapsedSeconds: 5,
        clientAttemptId: '44444444-4444-4444-8444-444444444444',
      ),
    );
    final retomado = await store.load(prova.id);
    expect(retomado!.clientAttemptId, '44444444-4444-4444-8444-444444444444');
  });

  test(
    'rascunho sobrevive a um reinício com armazenamento em arquivo',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('draft_restart');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final before = AttemptDraftStore(
        storage: PayloadDraftStorage(
          store: createLocalPayloadStore(directoryPath: directory.path),
        ),
      );
      await before.save(
        'exam',
        const AttemptDraft(
          answers: {0: 1, 1: 0},
          review: {1},
          current: 1,
          elapsedSeconds: 42,
          clientAttemptId: '77777777-7777-4777-8777-777777777777',
          examContentHash: 'hash-atual',
        ),
      );
      before.dispose();

      // Simula outro processo: uma nova instância lê o mesmo diretório.
      final after = AttemptDraftStore(
        storage: PayloadDraftStorage(
          store: createLocalPayloadStore(directoryPath: directory.path),
        ),
      );
      final retomado = await after.load('exam');
      expect(retomado!.answers, {0: 1, 1: 0});
      expect(retomado.review, {1});
      expect(retomado.current, 1);
      expect(retomado.elapsedSeconds, 42);
      expect(retomado.clientAttemptId, '77777777-7777-4777-8777-777777777777');
      expect(retomado.examContentHash, 'hash-atual');
      after.dispose();
    },
  );

  test(
    'o mesmo clientAttemptId com outro payload é recusado pela fila',
    () async {
      final fila = AttemptQueueStore(storage: _FilaMemoria());
      final prova = _prova([_par, _impar]);
      await fila.enqueue(
        AttemptSubmission(
          clientAttemptId: '55555555-5555-5555-8555-555555555555',
          exam: prova,
          answers: const {0: 1, 1: 0},
          markedForReview: const {},
          durationSeconds: 60,
          finishedAt: DateTime.utc(2026, 11, 5),
        ),
      );

      // Retomar o rascunho e responder de outro jeito reutiliza o mesmo ID
      // (quiz_page.dart:133), e a fila recusa em vez de sobrescrever a entrega.
      await expectLater(
        fila.enqueue(
          AttemptSubmission(
            clientAttemptId: '55555555-5555-5555-8555-555555555555',
            exam: prova,
            answers: const {0: 0, 1: 0},
            markedForReview: const {},
            durationSeconds: 61,
            finishedAt: DateTime.utc(2026, 11, 5),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('prova local não entra na fila de sincronização', () async {
    final fila = AttemptQueueStore(storage: _FilaMemoria());
    await expectLater(
      AttemptSyncService(store: fila).saveForSync(
        AttemptSubmission(
          clientAttemptId: '66666666-6666-6666-8666-666666666666',
          exam: Exam(
            id: 'local',
            category: 'Geral',
            title: 'Prova local',
            description: '',
            author: 'Fonte',
            durationMinutes: 30,
            attempts: 0,
            isLocal: true,
            questions: const [_par],
          ),
          answers: const {0: 1},
          markedForReview: const {},
          durationSeconds: 10,
          finishedAt: DateTime.utc(2026, 11, 5),
        ),
      ),
      throwsStateError,
    );
  });

  testWidgets('rascunho de outro conteúdo não é restaurado', (tester) async {
    // Criado dentro do teste: o store inicia uma Future no construtor, e uma
    // Future criada no setUp não avança sob o fake async do testWidgets.
    final widgetStore = AttemptDraftStore(storage: _RascunhoMemoria());
    final prova = _prova([_par, _impar]);
    await widgetStore.save(
      prova.id,
      const AttemptDraft(
        answers: {0: 1, 1: 0},
        review: {},
        current: 1,
        elapsedSeconds: 12,
        examContentHash: 'hash-de-uma-revisao-anterior',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(
          exam: prova,
          draftStore: widgetStore,
          syncService: AttemptSyncService(
            store: AttemptQueueStore(storage: _FilaMemoria()),
            submitter: _SemRede(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Questão 1 de 2'), findsOneWidget);
    expect(
      find.text('O conteúdo desta prova mudou. Comece uma nova tentativa.'),
      findsOneWidget,
    );
    // As respostas antigas continuam no aparelho, mas fora desta tentativa.
    expect((await widgetStore.load(prova.id))!.answers, {0: 1, 1: 0});

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    widgetStore.dispose();
  });
}

class _RascunhoMemoria implements DraftStorage {
  final Map<String, String> _valores = {};

  @override
  Future<String?> read(String key) async => _valores[key];

  @override
  Future<void> write(String key, String value) async => _valores[key] = value;

  @override
  Future<void> remove(String key) async => _valores.remove(key);
}

class _FilaMemoria implements AttemptQueueStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _SemRede implements AttemptSubmitter {
  @override
  Future<ExamResult> submit(AttemptSubmission submission) =>
      throw const AttemptSubmissionException(
        message: 'sem rede',
        transient: true,
      );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/core/backend/local_payload_store.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryQueueStorage implements AttemptQueueStorage {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('armazenamento indisponível');
    this.value = value;
  }
}

class BlockingQueueStorage implements AttemptQueueStorage {
  final entered = Completer<void>();
  final release = Completer<void>();
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    this.value = value;
  }
}

class FakeSubmitter implements AttemptSubmitter {
  FakeSubmitter({this.error});
  AttemptSubmissionException? error;
  int calls = 0;
  final ids = <String>[];

  @override
  Future<ExamResult> submit(AttemptSubmission submission) async {
    calls++;
    ids.add(submission.clientAttemptId);
    if (error case final failure?) throw failure;
    return ExamResult(
      exam: submission.exam.copyWith(
        questions: submission.exam.questions
            .map((question) => question.copyWith(correctIndex: 1))
            .toList(),
      ),
      answers: submission.answers,
      markedForReview: submission.markedForReview,
      durationSeconds: submission.durationSeconds,
      finishedAt: submission.finishedAt,
    );
  }
}

class ControlledSubmitter implements AttemptSubmitter {
  final gate = Completer<ExamResult>();
  int calls = 0;

  @override
  Future<ExamResult> submit(AttemptSubmission submission) {
    calls++;
    return gate.future;
  }
}

const exam = Exam(
  id: 'exam-1',
  category: 'Geral',
  title: 'Prova',
  description: '',
  author: 'Fonte',
  durationMinutes: 30,
  attempts: 0,
  year: 2024,
  board: 'VUNESP',
  institution: 'Polícia Militar de São Paulo',
  instance: 'Prova objetiva — Parte I',
  questions: [
    Question(id: 'q1', topic: 'Geral', statement: 'Q?', options: ['A', 'B']),
  ],
);

AttemptSubmission submission([
  String id = '11111111-1111-4111-8111-111111111111',
]) => AttemptSubmission(
  clientAttemptId: id,
  exam: exam,
  answers: const {'q1': 1},
  markedForReview: const {},
  durationSeconds: 10,
  finishedAt: DateTime.utc(2026, 9, 21),
);

void main() {
  test(
    'serializa por armazenamento sem bloquear bibliotecas independentes',
    () async {
      final blockedStorage = BlockingQueueStorage();
      final blockedStore = AttemptQueueStore(storage: blockedStorage);
      final blockedWrite = blockedStore.saveStartedExam(exam);
      await blockedStorage.entered.future;

      final independentStore = AttemptQueueStore(storage: MemoryQueueStorage());
      await independentStore
          .saveStartedExam(exam)
          .timeout(const Duration(seconds: 1));

      blockedStorage.release.complete();
      await blockedWrite;
    },
  );

  test(
    'entrega captura respostas antes de aguardar gravações anteriores',
    () async {
      final store = AttemptQueueStore(storage: MemoryQueueStorage());
      final answers = <String, int>{'q1': 1};
      final marked = <String>{'q1'};
      final value = AttemptSubmission(
        clientAttemptId: submission().clientAttemptId,
        exam: exam,
        answers: answers,
        markedForReview: marked,
        durationSeconds: 10,
        finishedAt: DateTime.utc(2026, 9, 26),
      );
      final writing = store.enqueue(value);
      answers['q1'] = 0;
      marked.clear();
      await writing;
      final persisted = (await store.pending()).single.submission;
      expect(persisted.answers, {'q1': 1});
      expect(persisted.markedForReview, {'q1'});
    },
  );

  test(
    'conteúdo iniciado sobrevive ao reinício sem acesso ao servidor',
    () async {
      final storage = MemoryQueueStorage();
      await AttemptQueueStore(storage: storage).saveStartedExam(exam);
      final restored = await AttemptQueueStore(storage: storage).startedExams();
      expect(restored.single.id, exam.id);
      expect(restored.single.questions.single.options, ['A', 'B']);
      expect(restored.single.questions.single.correctIndex, isNull);
      expect(restored.single.sourceType, exam.sourceType);
      expect(restored.single.year, 2024);
      expect(restored.single.board, 'VUNESP');
      expect(restored.single.institution, 'Polícia Militar de São Paulo');
      expect(restored.single.instance, 'Prova objetiva — Parte I');
    },
  );

  test('entrega substitui conteúdo iniciado na mesma gravação', () async {
    final storage = MemoryQueueStorage();
    final store = AttemptQueueStore(storage: storage);
    await store.saveStartedExam(exam);
    storage.failWrites = true;
    await expectLater(store.enqueue(submission()), throwsStateError);
    expect((await store.startedExams()).single.id, exam.id);
    expect(await store.pending(), isEmpty);
    storage.failWrites = false;
    await store.enqueue(submission());
    final restarted = AttemptQueueStore(storage: storage);
    expect(await restarted.startedExams(), isEmpty);
    expect((await restarted.pending()).single.submission.exam.id, exam.id);
  });

  test(
    'resultado local persiste sem entrar na fila de sincronização',
    () async {
      final storage = MemoryQueueStorage();
      final store = AttemptQueueStore(storage: storage);
      final local = Exam(
        id: 'local',
        category: exam.category,
        title: exam.title,
        description: exam.description,
        author: exam.author,
        durationMinutes: exam.durationMinutes,
        attempts: 0,
        questions: [exam.questions.single.copyWith(correctIndex: 1)],
        isLocal: true,
      );
      final result = ExamResult(
        exam: local,
        answers: const {'q1': 1},
        markedForReview: const {'q1'},
        durationSeconds: 15,
        finishedAt: DateTime.utc(2026, 9, 26),
      );
      await store.saveStartedExam(local);
      storage.failWrites = true;
      await expectLater(
        store.completeLocal('local-attempt', result),
        throwsStateError,
      );
      expect((await store.startedExams()).single.id, local.id);
      storage.failWrites = false;
      await store.completeLocal('local-attempt', result);
      final restarted = AttemptQueueStore(storage: storage);
      expect(await restarted.startedExams(), isEmpty);
      expect(await restarted.pending(), isEmpty);
      final completed = (await restarted.completed())['local-attempt']!;
      expect(completed.correct, 1);
      expect(completed.markedForReview, {'q1'});
      expect(completed.durationSeconds, 15);
      expect(completed.exam.isLocal, isTrue);
    },
  );

  test('finalização online armazena somente o resultado corrigido', () async {
    final storage = MemoryQueueStorage();
    final submitter = FakeSubmitter();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    await service.saveForSync(submission());
    final outcome = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(outcome.result!.correct, 1);
    expect(await service.store.pending(), isEmpty);
    expect((await service.store.completed()).length, 1);
  });

  test('finalização offline persiste fila e agenda backoff', () async {
    final storage = MemoryQueueStorage();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'sem rede',
          transient: true,
        ),
      ),
    );
    await service.saveForSync(submission());
    final outcome = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(outcome.attempt.state, AttemptSyncState.waitingConnection);
    expect(outcome.attempt.attemptCount, 1);
    expect(outcome.attempt.lastError, 'sem rede');
    expect(outcome.attempt.nextAttemptAt, isNotNull);
  });

  test('entrega visitante aguarda login e sincroniza com o mesmo ID', () async {
    final storage = MemoryQueueStorage();
    final submitter = FakeSubmitter(
      error: const AttemptSubmissionException(
        message: 'Entre na sua conta para sincronizar a entrega.',
        transient: false,
        requiresAuthentication: true,
      ),
    );
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    await service.saveForSync(submission());

    final waiting = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(waiting.attempt.state, AttemptSyncState.waitingAuthentication);
    expect(waiting.attempt.attemptCount, 0);
    expect(await service.store.pending(), hasLength(1));
    expect(await service.store.completed(), isEmpty);

    submitter.error = null;
    final synced = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(synced.result!.correct, 1);
    expect(submitter.ids, [
      submission().clientAttemptId,
      submission().clientAttemptId,
    ]);
    expect(await service.store.pending(), isEmpty);
    expect((await service.store.completed()).length, 1);
  });

  test('reinício restaura entrega e permite reenvio posterior', () async {
    final storage = MemoryQueueStorage();
    final offline = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'sem rede',
          transient: true,
        ),
      ),
    );
    await offline.saveForSync(submission());
    await offline.sync(submission().clientAttemptId, ignoreSchedule: true);

    final onlineSubmitter = FakeSubmitter();
    final restarted = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: onlineSubmitter,
    );
    final restored = (await restarted.store.pending()).single;
    expect(restored.attemptCount, 1);
    expect(restored.nextAttemptAt, isNotNull);
    final outcome = await restarted.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(outcome.result, isNotNull);
    expect(onlineSubmitter.ids.single, submission().clientAttemptId);
  });

  test('clientAttemptId duplicado ocupa uma única posição na fila', () async {
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: MemoryQueueStorage()),
      submitter: FakeSubmitter(),
    );
    await service.saveForSync(submission());
    await service.saveForSync(submission());
    expect((await service.store.pending()).length, 1);
  });

  test(
    'clientAttemptId não pode ser reutilizado com respostas diferentes',
    () async {
      final service = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: FakeSubmitter(),
      );
      final original = submission();
      await service.saveForSync(original);
      final changed = AttemptSubmission(
        clientAttemptId: original.clientAttemptId,
        exam: original.exam,
        answers: const {'q1': 0},
        markedForReview: original.markedForReview,
        durationSeconds: original.durationSeconds,
        finishedAt: original.finishedAt,
      );
      await expectLater(service.saveForSync(changed), throwsStateError);
    },
  );

  test(
    'reenvios simultâneos do mesmo clientAttemptId compartilham a RPC',
    () async {
      final submitter = ControlledSubmitter();
      final service = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: submitter,
      );
      final value = submission();
      await service.saveForSync(value);

      final first = service.sync(value.clientAttemptId, ignoreSchedule: true);
      final second = service.sync(value.clientAttemptId, ignoreSchedule: true);
      await Future<void>.delayed(Duration.zero);
      expect(submitter.calls, 1);

      submitter.gate.complete(
        ExamResult(
          exam: value.exam.copyWith(
            questions: value.exam.questions
                .map((question) => question.copyWith(correctIndex: 1))
                .toList(),
          ),
          answers: value.answers,
          markedForReview: value.markedForReview,
          durationSeconds: value.durationSeconds,
          finishedAt: value.finishedAt,
        ),
      );
      expect((await first).result, isNotNull);
      expect((await second).result, isNotNull);
    },
  );

  test(
    'armazenamentos independentes sincronizam sem bloquear um ao outro',
    () async {
      final blockedSubmitter = ControlledSubmitter();
      final blockedValue = submission();
      final blockedService = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: blockedSubmitter,
      );
      await blockedService.saveForSync(blockedValue);
      final blockedSync = blockedService.sync(
        blockedValue.clientAttemptId,
        ignoreSchedule: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(blockedSubmitter.calls, 1);

      final independentValue = submission(
        '22222222-2222-4222-8222-222222222222',
      );
      final independentService = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: FakeSubmitter(),
      );
      await independentService.saveForSync(independentValue);
      final independentOutcome = await independentService
          .sync(independentValue.clientAttemptId, ignoreSchedule: true)
          .timeout(const Duration(seconds: 1));
      expect(independentOutcome.result, isNotNull);

      blockedSubmitter.gate.complete(
        ExamResult(
          exam: blockedValue.exam.copyWith(
            questions: blockedValue.exam.questions
                .map((question) => question.copyWith(correctIndex: 1))
                .toList(),
          ),
          answers: blockedValue.answers,
          markedForReview: blockedValue.markedForReview,
          durationSeconds: blockedValue.durationSeconds,
          finishedAt: blockedValue.finishedAt,
        ),
      );
      expect((await blockedSync).result, isNotNull);
    },
  );

  test(
    'sincronizações de IDs diferentes no mesmo armazenamento são serializadas',
    () async {
      final submitter = ControlledSubmitter();
      final service = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: submitter,
      );
      final firstValue = submission();
      final secondValue = submission('22222222-2222-4222-8222-222222222222');
      await service.saveForSync(firstValue);
      await service.saveForSync(secondValue);

      final first = service.sync(
        firstValue.clientAttemptId,
        ignoreSchedule: true,
      );
      final second = service.sync(
        secondValue.clientAttemptId,
        ignoreSchedule: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(submitter.calls, 1);

      submitter.gate.complete(
        ExamResult(
          exam: firstValue.exam.copyWith(
            questions: firstValue.exam.questions
                .map((question) => question.copyWith(correctIndex: 1))
                .toList(),
          ),
          answers: firstValue.answers,
          markedForReview: firstValue.markedForReview,
          durationSeconds: firstValue.durationSeconds,
          finishedAt: firstValue.finishedAt,
        ),
      );
      await first;
      await second;
      expect(submitter.calls, 2);
    },
  );

  test('erro permanente requer atenção e não é reenviado', () async {
    final submitter = FakeSubmitter(
      error: const AttemptSubmissionException(
        message: 'entrega inválida',
        transient: false,
      ),
    );
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: MemoryQueueStorage()),
      submitter: submitter,
    );
    await service.saveForSync(submission());
    final first = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    final second = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(first.attempt.state, AttemptSyncState.requiresAttention);
    expect(second.attempt.state, AttemptSyncState.requiresAttention);
    expect(submitter.calls, 1);
  });

  test(
    'retry explícito recupera entrega após correção externa sem trocar ID',
    () async {
      final submitter = FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'serviço desatualizado',
          transient: false,
        ),
      );
      final storage = MemoryQueueStorage();
      final firstService = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: submitter,
      );
      final value = submission();
      await firstService.saveForSync(value);
      await firstService.sync(value.clientAttemptId);
      submitter.error = null;
      final restarted = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: submitter,
      );
      await restarted.syncDue();
      expect(submitter.calls, 1);
      final retried = await restarted.sync(
        value.clientAttemptId,
        ignoreSchedule: true,
        retryAttention: true,
      );
      expect(retried.result!.answers, value.answers);
      expect(submitter.ids, [value.clientAttemptId, value.clientAttemptId]);
      expect(await restarted.store.pending(), isEmpty);
      expect(await restarted.store.completed(), hasLength(1));
    },
  );

  test('backoff é limitado a uma hora', () async {
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: MemoryQueueStorage()),
      submitter: FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'sem rede',
          transient: true,
        ),
      ),
    );
    await service.saveForSync(submission());
    AttemptSyncOutcome? outcome;
    for (var index = 0; index < 7; index++) {
      outcome = await service.sync(
        submission().clientAttemptId,
        ignoreSchedule: true,
      );
    }
    final delay = outcome!.attempt.nextAttemptAt!.difference(DateTime.now());
    expect(delay <= const Duration(hours: 1), isTrue);
    expect(outcome.attempt.attemptCount, 7);
  });

  test('falha ao salvar fila é propagada sem item parcial', () async {
    final storage = MemoryQueueStorage()..failWrites = true;
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: FakeSubmitter(),
    );
    await expectLater(service.saveForSync(submission()), throwsStateError);
    storage.failWrites = false;
    expect(await service.store.pending(), isEmpty);
  });

  test('migra a fila antiga para arquivo e remove o legado', () async {
    SharedPreferences.setMockInitialValues({
      'attempt_sync_queue_v1': 'fila-antiga',
    });
    final directory = await Directory.systemTemp.createTemp('queue_migration');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final storage = PayloadQueueStorage(
      store: createLocalPayloadStore(directoryPath: directory.path),
    );

    expect(await storage.read(), 'fila-antiga');
    expect(
      await File('${directory.path}/attempt_sync_queue_v1.json').exists(),
      isTrue,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('attempt_sync_queue_v1'), isNull);
  });

  test('grava a fila no arquivo novo', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('queue_write');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final storage = PayloadQueueStorage(
      store: createLocalPayloadStore(directoryPath: directory.path),
    );

    await storage.write('fila-nova');
    expect(await storage.read(), 'fila-nova');
    expect(
      await File('${directory.path}/attempt_sync_queue_v1.json').readAsString(),
      'fila-nova',
    );
  });

  test('falha do arquivo mantém a fila em preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PayloadQueueStorage(store: _FailingQueuePayloadStore());

    await storage.write('fila-reserva');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('attempt_sync_queue_v1'), 'fila-reserva');
    expect(await storage.read(), 'fila-reserva');
  });
}

class _FailingQueuePayloadStore implements LocalPayloadStore {
  @override
  bool get fileBacked => true;

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<String?> readBackup(String key) async => null;

  @override
  Future<bool> write(
    String key,
    String payload, {
    String? backupPayload,
  }) async => false;

  @override
  Future<bool> remove(String key) async => false;
}

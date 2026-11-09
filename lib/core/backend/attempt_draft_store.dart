import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_payload_store.dart';
import 'payload_storage_migration.dart';

class AttemptDraft {
  const AttemptDraft({
    required this.answers,
    required this.review,
    required this.current,
    required this.elapsedSeconds,
    this.clientAttemptId,
    this.examContentHash,
  });

  final Map<int, int> answers;
  final Set<int> review;
  final int current;
  final int elapsedSeconds;
  final String? clientAttemptId;

  /// Hash da revisão de conteúdo resolvida. Rascunhos antigos não têm o campo
  /// e continuam sendo restaurados como antes (ADR-0003).
  final String? examContentHash;

  AttemptDraft snapshot() => AttemptDraft(
    answers: Map.of(answers),
    review: Set.of(review),
    current: current,
    elapsedSeconds: elapsedSeconds,
    clientAttemptId: clientAttemptId,
    examContentHash: examContentHash,
  );
}

enum DraftSaveStatus { saving, saved, failed }

abstract class DraftStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class PayloadDraftStorage implements DraftStorage {
  PayloadDraftStorage({LocalPayloadStore? store})
    : _store = store ?? createLocalPayloadStore();

  final LocalPayloadStore _store;

  @override
  Future<String?> read(String key) => readMigratingPayload(_store, key);

  @override
  Future<void> write(String key, String value) =>
      writeMigratingPayload(_store, key, value);

  @override
  Future<void> remove(String key) => removeMigratingPayload(_store, key);
}

class AttemptDraftStore {
  AttemptDraftStore({DraftStorage? storage})
    : _storage = storage ?? _defaultStorage;

  static final _defaultStorage = PayloadDraftStorage();

  final DraftStorage _storage;
  final status = ValueNotifier<DraftSaveStatus>(DraftSaveStatus.saved);
  Future<void> _tail = Future<void>.value();
  AttemptDraft? _latest;
  String? _examId;
  int _revision = 0;
  int _savedRevision = 0;
  bool _disposed = false;

  String _key(String examId) => 'attempt_draft_v1_$examId';

  // A fila continua utilizável mesmo depois de uma gravação que falhou.
  Future<void> _enqueue(String examId, AttemptDraft draft, int revision) {
    status.value = DraftSaveStatus.saving;
    final operation = _tail.then((_) async {
      await _storage.write(
        _key(examId),
        jsonEncode({
          'answers': draft.answers.map((key, value) => MapEntry('$key', value)),
          'review': draft.review.toList(),
          'current': draft.current,
          'elapsedSeconds': draft.elapsedSeconds,
          'clientAttemptId': draft.clientAttemptId,
          'examContentHash': draft.examContentHash,
        }),
      );
      if (revision > _savedRevision) _savedRevision = revision;
      if (!_disposed && revision == _revision) {
        status.value = DraftSaveStatus.saved;
      }
    });
    _tail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (!_disposed && revision == _revision) {
          status.value = DraftSaveStatus.failed;
        }
      },
    );
    return _tail;
  }

  Future<void> save(String examId, AttemptDraft draft) {
    _examId = examId;
    _latest = draft.snapshot();
    return _enqueue(examId, _latest!, ++_revision);
  }

  // Aguarda tudo que já foi enfileirado e recupera a última versão se falhou.
  Future<void> flush() async {
    while (true) {
      final pending = _tail;
      await pending;
      if (!identical(pending, _tail)) continue;
      if (_latest == null || _savedRevision == _revision) return;
      final retryRevision = _revision;
      await _enqueue(_examId!, _latest!, retryRevision);
      if (_revision != retryRevision) continue;
      if (_savedRevision != retryRevision) {
        throw StateError('Não foi possível salvar o rascunho no aparelho.');
      }
      return;
    }
  }

  Future<AttemptDraft?> load(String examId) async {
    final raw = await _storage.read(_key(examId));
    if (raw == null) return null;
    final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final answers = Map<String, dynamic>.from(json['answers'] as Map);
    return AttemptDraft(
      answers: answers.map(
        (key, value) => MapEntry(int.parse(key), value as int),
      ),
      review: Set<int>.from(json['review'] as List),
      current: json['current'] as int,
      elapsedSeconds: json['elapsedSeconds'] as int,
      clientAttemptId: json['clientAttemptId'] as String?,
      examContentHash: json['examContentHash'] as String?,
    );
  }

  Future<void> clear(String examId) async {
    await flush();
    await _storage.remove(_key(examId));
    _latest = null;
    _examId = null;
    _savedRevision = _revision;
  }

  void dispose() {
    _disposed = true;
    status.dispose();
  }
}

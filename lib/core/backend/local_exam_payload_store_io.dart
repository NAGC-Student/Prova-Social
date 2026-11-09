import 'local_exam_payload_store.dart';
import 'local_payload_store.dart';

/// Adapter da prova privada sobre o armazenamento atômico por chave.
class LocalExamPayloadStore implements ExamPayloadStorage {
  LocalExamPayloadStore({LocalPayloadStore? store})
    : _store = store ?? createLocalPayloadStore();

  static const key = 'private_exams_v1';
  final LocalPayloadStore _store;

  @override
  bool get fileBacked => _store.fileBacked;

  @override
  Future<String?> read() => _store.read(key);

  @override
  Future<String?> readBackup() => _store.readBackup(key);

  @override
  Future<bool> write(String payload, {String? backupPayload}) =>
      _store.write(key, payload, backupPayload: backupPayload);

  @override
  Future<bool> migrate(String payload) async {
    if (await read() != null) return true;
    return write(payload, backupPayload: '[]');
  }
}

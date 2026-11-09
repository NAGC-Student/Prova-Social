export 'local_payload_store_stub.dart'
    if (dart.library.io) 'local_payload_store_io.dart'
    show createLocalPayloadStore;

/// Armazenamento durável de um payload por chave.
///
/// A implementação de IO grava um arquivo temporário com `flush: true` e faz
/// rename atômico; a versão anterior fica no backup. No browser, a
/// implementação usa `SharedPreferences` e declara `fileBacked == false`.
abstract interface class LocalPayloadStore {
  bool get fileBacked;

  Future<String?> read(String key);
  Future<String?> readBackup(String key);

  /// Retorna `false` quando a plataforma não consegue persistir (web) ou
  /// quando a escrita em arquivo falha de forma recuperável.
  Future<bool> write(String key, String payload, {String? backupPayload});

  /// Remove o payload principal e o backup. É idempotente.
  Future<bool> remove(String key);
}

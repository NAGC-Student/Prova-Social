import 'package:shared_preferences/shared_preferences.dart';

import 'local_payload_store.dart';

/// Fallback de browser. O web não expõe um diretório de arquivos do app, então
/// a persistência continua em `SharedPreferences` e `fileBacked` é `false`.
LocalPayloadStore createLocalPayloadStore({String? directoryPath}) =>
    _PreferencesLocalPayloadStore();

class _PreferencesLocalPayloadStore implements LocalPayloadStore {
  static const _prefix = 'payload_v1_';

  String _key(String key) => '$_prefix$key';
  String _backupKey(String key) => '$_prefix${key}_backup';

  @override
  bool get fileBacked => false;

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(_key(key));

  @override
  Future<String?> readBackup(String key) async =>
      (await SharedPreferences.getInstance()).getString(_backupKey(key));

  @override
  Future<bool> write(
    String key,
    String payload, {
    String? backupPayload,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString(_key(key));
    final backup = backupPayload ?? current;
    final backupOk = backup == null
        ? true
        : await preferences.setString(_backupKey(key), backup);
    final payloadOk = await preferences.setString(_key(key), payload);
    return backupOk && payloadOk;
  }

  @override
  Future<bool> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final backupOk = await preferences.remove(_backupKey(key));
    final payloadOk = await preferences.remove(_key(key));
    return backupOk && payloadOk;
  }
}

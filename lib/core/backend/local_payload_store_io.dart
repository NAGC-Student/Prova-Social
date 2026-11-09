import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'local_payload_store.dart';

LocalPayloadStore createLocalPayloadStore({String? directoryPath}) =>
    _IoLocalPayloadStore(directoryPath);

class _IoLocalPayloadStore implements LocalPayloadStore {
  _IoLocalPayloadStore([this._directoryPath]);

  final String? _directoryPath;

  @override
  bool get fileBacked => true;

  Future<Directory> _directory() async {
    final directory = _directoryPath == null
        ? await getApplicationSupportDirectory()
        : Directory(_directoryPath);
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<String?> read(String key) async {
    final file = File('${(await _directory()).path}/${_fileName(key)}');
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<String?> readBackup(String key) async {
    final file = File('${(await _directory()).path}/${_fileName(key)}.bak');
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<bool> write(
    String key,
    String payload, {
    String? backupPayload,
  }) async {
    final directory = await _directory();
    final name = _fileName(key);
    final current = File('${directory.path}/$name');
    final backup = File('${directory.path}/$name.bak');
    final temporary = File('${directory.path}/$name.tmp');
    final backupTemporary = File('${directory.path}/$name.bak.tmp');
    try {
      if (await current.exists()) {
        if (backupPayload == null) {
          await current.copy(backupTemporary.path);
        } else {
          await backupTemporary.writeAsString(backupPayload, flush: true);
        }
        if (await backup.exists()) await backup.delete();
        await backupTemporary.rename(backup.path);
      } else if (backupPayload != null) {
        await backupTemporary.writeAsString(backupPayload, flush: true);
        if (await backup.exists()) await backup.delete();
        await backupTemporary.rename(backup.path);
      }
      await temporary.writeAsString(payload, flush: true);
      await temporary.rename(current.path);
      return true;
    } on FileSystemException {
      return false;
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if (await backupTemporary.exists()) await backupTemporary.delete();
    }
  }

  @override
  Future<bool> remove(String key) async {
    final directory = await _directory();
    final name = _fileName(key);
    final current = File('${directory.path}/$name');
    final backup = File('${directory.path}/$name.bak');
    try {
      if (await current.exists()) await current.delete();
      if (await backup.exists()) await backup.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Nomes seguros preservam o arquivo legado; nomes com caracteres especiais
  /// recebem um sufixo de hash para não colidirem entre si.
  String _fileName(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'A chave não pode ser vazia.');
    }
    final sanitized = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized == key && key.length <= 120) return '$key.json';
    final hash = sha256.convert(utf8.encode(key)).toString();
    final clipped = sanitized.length <= 100
        ? sanitized
        : sanitized.substring(0, 100);
    return '${clipped}_${hash.substring(0, 12)}.json';
  }
}

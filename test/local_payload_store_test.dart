import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/local_payload_store.dart';
import 'package:prova_social/core/backend/local_payload_store_stub.dart' as web;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late LocalPayloadStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('payload_store_test');
    store = createLocalPayloadStore(directoryPath: directory.path);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('escreve, lê e mantém a versão anterior no backup', () async {
    expect(store.fileBacked, isTrue);
    expect(await store.read('private_exams_v1'), isNull);
    expect(await store.readBackup('private_exams_v1'), isNull);

    expect(await store.write('private_exams_v1', 'v1'), isTrue);
    expect(await store.read('private_exams_v1'), 'v1');
    expect(await store.readBackup('private_exams_v1'), isNull);

    expect(await store.write('private_exams_v1', 'v2'), isTrue);
    expect(await store.read('private_exams_v1'), 'v2');
    expect(await store.readBackup('private_exams_v1'), 'v1');

    expect(
      await store.write(
        'private_exams_v1',
        'v3',
        backupPayload: 'backup-explicito',
      ),
      isTrue,
    );
    expect(await store.read('private_exams_v1'), 'v3');
    expect(await store.readBackup('private_exams_v1'), 'backup-explicito');
  });

  test('payload atual corrompido pode ser recuperado pelo backup', () async {
    await store.write('private_exams_v1', 'versao-valida');
    await store.write('private_exams_v1', '{"quebrado":');

    final current = File('${directory.path}/private_exams_v1.json');
    expect(await current.readAsString(), '{"quebrado":');
    expect(await store.readBackup('private_exams_v1'), 'versao-valida');
  });

  test('remove o payload e o backup de forma idempotente', () async {
    await store.write('attempt_sync_queue_v1', 'fila');
    await store.write('attempt_sync_queue_v1', 'fila-nova');

    expect(await store.remove('attempt_sync_queue_v1'), isTrue);
    expect(await store.read('attempt_sync_queue_v1'), isNull);
    expect(await store.readBackup('attempt_sync_queue_v1'), isNull);
    expect(await store.remove('attempt_sync_queue_v1'), isTrue);
  });

  test('chave segura preserva o nome de arquivo legado', () async {
    await store.write('private_exams_v1', 'x');
    expect(
      await File('${directory.path}/private_exams_v1.json').exists(),
      isTrue,
    );
  });

  test('chaves com caracteres especiais não colidem', () async {
    const first = 'attempt_draft_v1_exam/with space';
    const second = 'attempt_draft_v1_exam?with space';
    await store.write(first, 'primeiro');
    await store.write(second, 'segundo');

    expect(await store.read(first), 'primeiro');
    expect(await store.read(second), 'segundo');

    final names = await directory
        .list()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();
    expect(names, hasLength(2));
    expect(names.every((name) => name.endsWith('.json')), isTrue);
    expect(names.any((name) => name.contains('/')), isFalse);
    expect(names.any((name) => name.contains(' ')), isFalse);
  });

  test('chave vazia é recusada', () async {
    await expectLater(store.write('', 'x'), throwsA(isA<ArgumentError>()));
  });

  test(
    'fallback de browser usa SharedPreferences e não é fileBacked',
    () async {
      SharedPreferences.setMockInitialValues({});
      final browser = web.createLocalPayloadStore();
      expect(browser.fileBacked, isFalse);

      expect(await browser.write('attention', 'v1'), isTrue);
      expect(await browser.read('attention'), 'v1');
      expect(await browser.readBackup('attention'), isNull);

      expect(await browser.write('attention', 'v2'), isTrue);
      expect(await browser.read('attention'), 'v2');
      expect(await browser.readBackup('attention'), 'v1');

      expect(await browser.remove('attention'), isTrue);
      expect(await browser.read('attention'), isNull);
      expect(await browser.readBackup('attention'), isNull);
    },
  );
}

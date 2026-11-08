import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> corpus;
  late List<Map<String, dynamic>> benchmarks;

  setUpAll(() async {
    corpus = jsonDecode(
      await File('test/fixtures/import_corpus.json').readAsString(),
    ) as Map<String, dynamic>;
    benchmarks = (corpus['benchmarks'] as List).cast<Map<String, dynamic>>();
  });

  test('manifesto declara schema e pelo menos um benchmark', () {
    expect(corpus['schemaVersion'], 1);
    expect(benchmarks, isNotEmpty);
    final ids = benchmarks.map((item) => item['id'] as String).toList();
    expect(ids.every((id) => id.trim().isNotEmpty), isTrue);
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('todo benchmark registra licença e limites de uso', () {
    for (final benchmark in benchmarks) {
      final id = benchmark['id'] as String;
      final source = benchmark['source'] as Map<String, dynamic>;
      final reason = 'Entrada $id de test/fixtures/import_corpus.json';

      expect(source['kind'], isA<String>(), reason: reason);
      expect((source['kind'] as String).trim(), isNotEmpty, reason: reason);
      expect(source['description'], isA<String>(), reason: reason);
      expect(
        (source['description'] as String).trim(),
        isNotEmpty,
        reason: reason,
      );

      expect(source['licenseStatus'], isA<String>(), reason: reason);
      expect(
        (source['licenseStatus'] as String).trim(),
        isNotEmpty,
        reason:
            '$reason: licenseStatus é obrigatório mesmo em material '
            'sintético; use project-generated quando o projeto criou o arquivo.',
      );
      expect(source['allowedForTesting'], isA<bool>(), reason: reason);
      expect(source['allowedForProductContent'], isA<bool>(), reason: reason);
    }
  });

  test('uso em produto exige licença verificada', () {
    for (final benchmark in benchmarks) {
      final source = benchmark['source'] as Map<String, dynamic>;
      if (source['allowedForProductContent'] != true) continue;
      expect(
        source['licenseStatus'],
        isNot('not-verified'),
        reason:
            'Entrada ${benchmark['id']}: allowedForProductContent só é '
            'permitido com licenseStatus verificado.',
      );
    }
  });

  test('todo documento registrado existe no caminho declarado', () {
    for (final benchmark in benchmarks) {
      final document = benchmark['document'] as Map<String, dynamic>;
      final path = document['path'] as String;
      expect(path, isNotEmpty);
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'Entrada ${benchmark['id']}: $path não existe.',
      );
      expect(document['sha256'], isA<String>());
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(document['sha256'] as String),
        isTrue,
        reason:
            'Entrada ${benchmark['id']}: sha256 deve ter 64 dígitos '
            'hexadecimais minúsculos.',
      );
    }
  });

  test('nenhum backup de fixture fica versionado ao lado do original', () {
    final backups = Directory('test/fixtures')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.backup'))
        .map((file) => file.path)
        .toList();
    expect(
      backups,
      isEmpty,
      reason:
          'Remova a duplicata; o original já está no Git e o hash no '
          'manifesto cobre a integridade.',
    );
  });
}

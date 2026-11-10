import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:prova_social/core/import/exam_metadata_suggester.dart';

Future<void> main(List<String> arguments) async {
  final root = Directory(
    arguments.isEmpty ? 'build/qa/military-exams' : arguments.single,
  ).absolute;
  final manifest = File(
    '${root.path}${Platform.pathSeparator}datasets'
    '${Platform.pathSeparator}manifests'
    '${Platform.pathSeparator}documents.jsonl',
  );
  if (!await manifest.exists()) {
    throw FileSystemException('Corpus manifest not found.', manifest.path);
  }

  final records = manifest
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .where(
        (record) =>
            record['status'] == 'downloaded' &&
            record['document_type'] == 'prova',
      );
  for (final record in records) {
    final relativePath = record['local_path'];
    if (relativePath is! String ||
        relativePath.isEmpty ||
        File(relativePath).isAbsolute ||
        relativePath.split(RegExp(r'[/\\]')).contains('..')) {
      throw FormatException(
        'Invalid corpus path for ${record['document_id']}.',
      );
    }

    final file = File(
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!await file.exists()) {
      throw FileSystemException('Corpus document is missing.', file.path);
    }
    final canonicalFile = await file.resolveSymbolicLinks();
    final canonicalRoot = await root.resolveSymbolicLinks();
    if (!canonicalFile.startsWith('$canonicalRoot${Platform.pathSeparator}')) {
      throw FormatException(
        'Corpus path escapes the root for ${record['document_id']}.',
      );
    }
    final expectedHash = record['sha256'];
    if (expectedHash is! String ||
        sha256.convert(await file.readAsBytes()).toString() != expectedHash) {
      throw FormatException('SHA-256 mismatch for ${record['document_id']}.');
    }
    final extraction = await Process.run('pdftotext', [
      '-f',
      '1',
      '-l',
      '5',
      '-layout',
      file.path,
      '-',
    ]);
    if (extraction.exitCode != 0) {
      throw ProcessException(
        'pdftotext',
        ['-f', '1', '-l', '5', '-layout', file.path, '-'],
        extraction.stderr.toString(),
        extraction.exitCode,
      );
    }
    final pages = extraction.stdout.toString().split('\f').take(5).toList();
    final suggestion = suggestExamMetadata(
      fileName: relativePath,
      firstPageText: pages.firstOrNull ?? '',
      pages: pages,
    );
    stdout.writeln(
      jsonEncode({
        'documentId': record['document_id'],
        'source': record['banca'],
        'groundTruthYear': record['year'],
        'suggested': {
          'title': suggestion.title,
          'year': suggestion.year,
          'category': suggestion.category,
          'board': suggestion.board,
          'institution': suggestion.institution,
          'instance': suggestion.instance,
        },
        'evidencePages': suggestion.evidencePages,
        'evidenceSources': suggestion.evidenceSources,
        'fieldsNeedingAttention': suggestion.fieldsNeedingAttention,
      }),
    );
  }
}

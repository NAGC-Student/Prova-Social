import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  final corpusPath = Platform.environment['PROVA_SOCIAL_CORPUS_ROOT'];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test(
    'benchmarks the universal parser against local corpus exam PDFs',
    skip: corpusPath == null || corpusPath.trim().isEmpty
        ? 'Set PROVA_SOCIAL_CORPUS_ROOT to run the local corpus benchmark.'
        : false,
    () async {
      final root = Directory(corpusPath!).absolute;
      final canonicalRoot = await root.resolveSymbolicLinks();
      final manifestFile = File(
        '${root.path}${Platform.pathSeparator}datasets'
        '${Platform.pathSeparator}manifests${Platform.pathSeparator}documents.jsonl',
      );
      if (!await manifestFile.exists()) {
        throw FileSystemException(
          'Corpus document manifest was not found.',
          manifestFile.path,
        );
      }

      final parserBytes = await File('lib/core/import/question_parser.dart')
          .readAsBytes();
      final parserSha256 = sha256.convert(parserBytes).toString();
      const pipelineFiles = [
        'lib/core/import/question_parser.dart',
        'lib/core/import/pdf_text_extractor.dart',
        'lib/core/import/import_quality_gate.dart',
        'lib/core/import/text_normalizer.dart',
        'lib/core/import/page_furniture_filter.dart',
        'lib/core/import/ocr_router.dart',
        'lib/core/import/ocr_layout_orderer.dart',
      ];
      final pipelineFileDigests = <String>[];
      for (final path in pipelineFiles) {
        final digest = sha256.convert(await File(path).readAsBytes());
        pipelineFileDigests.add('$path:$digest');
      }
      final pipelineSha256 = sha256
          .convert(utf8.encode(pipelineFileDigests.join('\n')))
          .toString();
      final reportFile = File('build/qa/corpus-benchmark.json');
      final previousReport = await _readPreviousReport(reportFile);
      final records = manifestFile
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .toList();
      final previousByHash = {
        for (final result in previousReport?['documents'] as List? ?? const [])
          if (result is Map<String, dynamic> &&
              result['documentSha256'] is String)
            result['documentSha256'] as String: result,
      };
      final manifestDuplicates = records
          .where((record) => record['status'] == 'duplicate')
          .length;
      final seenHashes = <String>{};
      final examRecords =
          records
              .where(
                (record) =>
                    record['status'] == 'downloaded' &&
                    record['document_type'] == 'prova',
              )
              .toList()
            ..sort((a, b) {
              final institution = '${a['banca']}'.compareTo('${b['banca']}');
              if (institution != 0) return institution;
              final year = '${a['year']}'.compareTo('${b['year']}');
              return year != 0
                  ? year
                  : '${a['document_id']}'.compareTo('${b['document_id']}');
            });

      final documents = <Map<String, Object?>>[];
      for (final record in examRecords) {
        final documentHash = record['sha256'];
        if (documentHash is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(documentHash)) {
          throw FormatException(
            'Invalid SHA-256 for ${record['document_id']}.',
          );
        }
        if (!seenHashes.add(documentHash)) continue;
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
          throw FileSystemException('Manifest document is missing.', file.path);
        }
        final canonicalFile = await file.resolveSymbolicLinks();
        if (!canonicalFile.startsWith(
          '$canonicalRoot${Platform.pathSeparator}',
        )) {
          throw FormatException(
            'Manifest path escapes the corpus root for ${record['document_id']}.',
          );
        }
        final bytes = await file.readAsBytes();
        final actualHash = sha256.convert(bytes).toString();
        if (actualHash != documentHash) {
          throw FormatException(
            'SHA-256 mismatch for ${record['document_id']}.',
          );
        }

        final stopwatch = Stopwatch()..start();
        final extraction = await const PdfTextExtractor().extract(
          bytes,
          sourceName: relativePath,
        );
        final questions = const QuestionParser().parsePages(
          extraction.pages.map((page) => page.text).toList(growable: false),
        );
        const qualityGate = ImportQualityGate();
        qualityGate.markNumberingIssues(questions);
        final quality = qualityGate.assess(extraction, questions);
        stopwatch.stop();

        final expectedCount = record['expected_question_count'];
        final previous = previousByHash[documentHash];
        documents.add({
          'documentId': record['document_id'],
          'institution': record['banca'],
          'title': record['title'],
          'sourceUrl': record['url'],
          'year': record['year'],
          'documentSha256': documentHash,
          'licenseStatus': record['license_status'] ?? 'unknown',
          'redistribution': record['redistribution'] ?? 'unknown',
          'expectedQuestions': expectedCount is int ? expectedCount : null,
          'expectedCountSource': record['expected_count_source'],
          'detectedQuestions': questions.length,
          'duplicateQuestions': quality.duplicateQuestionCount,
          'incompleteQuestions': quality.incompleteQuestionCount,
          'numberingIssues': quality.numberingIssues,
          'questionsNeedingReview': quality.questionsNeedingReview,
          'questionsWithVisualWarnings': questions
              .where(
                (question) =>
                    question.warnings.any(
                      (warning) =>
                          warning.toLowerCase().contains('conteúdo visual'),
                    ) ||
                    (question.warning?.toLowerCase().contains(
                          'conteúdo visual',
                        ) ??
                        false),
              )
              .length,
          'pages': extraction.pageCount,
          'ocrAvailableInRunner': extraction.ocrAvailable,
          'ocrPages': extraction.ocrPages,
          'unreadablePages': quality.unreadablePages,
          'processingMilliseconds': stopwatch.elapsedMilliseconds,
          'qualityStatus': quality.status.name,
          'comparison': previous == null
              ? null
              : {
                  'previousDetectedQuestions': previous['detectedQuestions'],
                  'detectedQuestionsDelta':
                      questions.length -
                      ((previous['detectedQuestions'] as num?)?.toInt() ?? 0),
                  'previousQuestionsNeedingReview':
                      previous['questionsNeedingReview'],
                  'questionsNeedingReviewDelta':
                      quality.questionsNeedingReview -
                      ((previous['questionsNeedingReview'] as num?)?.toInt() ??
                          0),
                  'previousPipelineSha256': previousReport?['pipelineSha256'],
                },
        });
      }

      final expectedRecords = documents
          .where((document) => document['expectedQuestions'] is int)
          .toList(growable: false);
      final detectedTotal = documents.fold<int>(
        0,
        (sum, document) => sum + (document['detectedQuestions']! as int),
      );
      final expectedTotal = expectedRecords.fold<int>(
        0,
        (sum, document) => sum + (document['expectedQuestions']! as int),
      );
      final report = <String, Object?>{
        'schemaVersion': 1,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'corpusRoot': root.path,
        'parserSha256': parserSha256,
        'pipelineSha256': pipelineSha256,
        'previousPipelineSha256': previousReport?['pipelineSha256'],
        'baselineAvailable': previousReport != null,
        'summary': {
          'manifestRecords': records.length,
          'manifestDuplicateRecords': manifestDuplicates,
          'examDocumentsProcessed': documents.length,
          'documentsWithNoDetectedQuestions': documents
              .where((document) => document['detectedQuestions'] == 0)
              .length,
          'expectedCountKnownDocuments': expectedRecords.length,
          'expectedQuestionTotal': expectedRecords.isEmpty
              ? null
              : expectedTotal,
          'detectedQuestionTotal': detectedTotal,
          'questionsNeedingReview': documents.fold<int>(
            0,
            (sum, document) =>
                sum + (document['questionsNeedingReview']! as int),
          ),
          'duplicateQuestions': documents.fold<int>(
            0,
            (sum, document) => sum + (document['duplicateQuestions']! as int),
          ),
          'incompleteQuestions': documents.fold<int>(
            0,
            (sum, document) => sum + (document['incompleteQuestions']! as int),
          ),
          'questionsWithVisualWarnings': documents.fold<int>(
            0,
            (sum, document) =>
                sum + (document['questionsWithVisualWarnings']! as int),
          ),
          'unreadablePages': documents.fold<int>(
            0,
            (sum, document) => sum + (document['unreadablePages']! as int),
          ),
          'questionCountRecall':
              expectedRecords.length == documents.length && expectedTotal > 0
              ? documents.fold<int>(
                      0,
                      (sum, document) =>
                          sum + (document['detectedQuestions']! as int),
                    ) /
                    expectedTotal
              : null,
          'visualPreservationRate': null,
          'visualPreservationNote': 'No annotated visual-content reference is available; warning counts are not a preservation score.',
          'ocrEvaluated': false,
          'ocrEvaluationNote': 'This host benchmark runs the native-text path only; native OCR engines are not loaded by the Linux test runner.',
          'processingMilliseconds': documents.fold<int>(
            0,
            (sum, document) =>
                sum + (document['processingMilliseconds']! as int),
          ),
        },
        'documents': documents,
      };
      await reportFile.parent.create(recursive: true);
      await reportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );

      expect(documents, isNotEmpty);
      expect(
        report['summary'],
        isA<Map<String, Object?>>().having(
          (summary) => summary['examDocumentsProcessed'],
          'exam document count',
          documents.length,
        ),
      );
    },
  );
}

Future<Map<String, dynamic>?> _readPreviousReport(File reportFile) async {
  if (!await reportFile.exists()) return null;
  final decoded = jsonDecode(await reportFile.readAsString());
  return decoded is Map<String, dynamic> &&
          decoded['documents'] is List &&
          decoded['pipelineSha256'] is String
      ? decoded
      : null;
}

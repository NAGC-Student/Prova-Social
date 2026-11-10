import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/answer_key_parser.dart';
import 'package:prova_social/core/import/exam_metadata_suggester.dart';
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
        final metadataPages = extraction.pages
            .take(5)
            .map((page) => '${page.text}\n${page.nativeText}')
            .toList(growable: false);
        final metadata = suggestExamMetadata(
          fileName: relativePath,
          firstPageText: metadataPages.firstOrNull ?? '',
          pages: metadataPages,
        );
        const qualityGate = ImportQualityGate();
        qualityGate.markNumberingIssues(questions);
        final quality = qualityGate.assess(extraction, questions);
        stopwatch.stop();

        final expectedCount = record['expected_question_count'];
        final previous = previousByHash[documentHash];
        final optionDistribution = <String, int>{};
        for (final question in questions) {
          final count = question.options.length.toString();
          optionDistribution.update(
            count,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        documents.add({
          'documentId': record['document_id'],
          'board': record['board'] ?? record['banca'],
          'institution': record['institution'],
          'title': record['title'],
          'sourceUrl': record['url'],
          'year': record['year'],
          'documentSha256': documentHash,
          'licenseStatus': record['license_status'] ?? 'unknown',
          'redistribution': record['redistribution'] ?? 'unknown',
          'expectedQuestions': expectedCount is int ? expectedCount : null,
          'minimumQuestions': record['minimum_question_count'] is int
              ? record['minimum_question_count']
              : null,
          'expectedCountSource': record['expected_count_source'],
          'questionCountAgreement': expectedCount is int
              ? questions.length == expectedCount
              : null,
          'minimumQuestionCountMet': record['minimum_question_count'] is int
              ? questions.length >= (record['minimum_question_count'] as int)
              : null,
          'detectedQuestions': questions.length,
          'questionSequence': [
            for (final question in questions)
              {
                'number': question.number,
                'sourcePage': question.sourcePage,
                'optionCount': question.options.length,
                'format': question.format.name,
              },
          ],
          'questionsWithAlternatives': questions
              .where((question) => question.options.length >= 2)
              .length,
          'questionsWithoutAlternatives': questions
              .where((question) => question.options.length < 2)
              .length,
          'optionCountDistribution': optionDistribution,
          'questionsContinuingAcrossPages': questions
              .where((question) => question.sourcePages.length > 1)
              .length,
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
          'metadataGroundTruth': record['metadata_ground_truth'],
          'metadata': {
            'suggested': {
              'title': metadata.title,
              'board': metadata.board,
              'institution': metadata.institution,
              'year': metadata.year,
              'category': metadata.category,
              'instance': metadata.instance,
            },
            'evidencePages': metadata.evidencePages,
            'evidenceSources': metadata.evidenceSources,
            'fieldsNeedingAttention': metadata.fieldsNeedingAttention,
          },
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

      final answerKeys = <Map<String, Object?>>[];
      for (final record in records.where(
        (record) =>
            record['status'] == 'downloaded' &&
            record['document_type'] == 'gabarito',
      )) {
        final relativePath = record['local_path'];
        if (relativePath is! String ||
            relativePath.isEmpty ||
            File(relativePath).isAbsolute ||
            relativePath.split(RegExp(r'[/\\]')).contains('..')) {
          throw FormatException(
            'Invalid answer-key path for ${record['document_id']}.',
          );
        }
        final file = File(
          '${root.path}${Platform.pathSeparator}'
          '${relativePath.replaceAll('/', Platform.pathSeparator)}',
        );
        if (!await file.exists()) {
          throw FileSystemException(
            'Manifest answer key is missing.',
            file.path,
          );
        }
        final actualHash = sha256.convert(await file.readAsBytes()).toString();
        if (actualHash != record['sha256']) {
          throw FormatException(
            'Answer-key SHA-256 mismatch for ${record['document_id']}.',
          );
        }
        final extraction = await const PdfTextExtractor().extract(
          await file.readAsBytes(),
          sourceName: relativePath,
        );
        final key = const AnswerKeyParser().parsePages(
          extraction.pages.map((page) => page.text).toList(growable: false),
        );
        if (key.isEmpty) {
          final pageSummary = extraction.pages
              .map(
                (page) =>
                    'page ${page.pageNumber} (${page.source.name}, '
                    '${page.text.length} chars, '
                    '${page.text.split('\n').length} lines)',
              )
              .join('; ');
          throw FormatException(
            'Official answer key contains no parseable entries: '
            '${record['document_id']}. $pageSummary',
          );
        }
        answerKeys.add({
          'documentId': record['document_id'],
          'relatedDocumentId': record['related_document_id'],
          'documentSha256': actualHash,
          'parsedAnswers': key.length,
          'parsedAnswerNumbers': key.byNumber.keys.toList()..sort(),
          'expectedAnswers': record['expected_answer_count'],
          'expectedAnswerNumbers': record['expected_answer_question_numbers'],
          'heading': key.heading,
          'pages': key.pages,
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
      final expectedAnswerRecords = answerKeys
          .where((answerKey) => answerKey['expectedAnswers'] is int)
          .toList(growable: false);
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
          'answerKeyDocumentsProcessed': answerKeys.length,
          'answerKeyDocumentsWithExpectedCount': expectedAnswerRecords.length,
          'expectedAnswerTotal': expectedAnswerRecords.isEmpty
              ? null
              : expectedAnswerRecords.fold<int>(
                  0,
                  (sum, answerKey) =>
                      sum + (answerKey['expectedAnswers']! as int),
                ),
          'parsedAnswerTotal': expectedAnswerRecords.isEmpty
              ? null
              : expectedAnswerRecords.fold<int>(
                  0,
                  (sum, answerKey) =>
                      sum + (answerKey['parsedAnswers']! as int),
                ),
          'answerKeysMatchingExpectedNumbers': expectedAnswerRecords
              .where(
                (answerKey) => listEquals(
                  answerKey['expectedAnswerNumbers'] as List?,
                  answerKey['parsedAnswerNumbers'] as List?,
                ),
              )
              .length,
          'documentsWithNoDetectedQuestions': documents
              .where((document) => document['detectedQuestions'] == 0)
              .length,
          'expectedCountKnownDocuments': expectedRecords.length,
          'expectedQuestionTotal': expectedRecords.isEmpty
              ? null
              : expectedTotal,
          'documentsMatchingExpectedQuestionCount': documents
              .where((document) => document['questionCountAgreement'] == true)
              .length,
          'documentsMeetingMinimumQuestionCount': documents
              .where((document) => document['minimumQuestionCountMet'] == true)
              .length,
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
          'questionCountRatio':
              expectedRecords.length == documents.length && expectedTotal > 0
              ? detectedTotal / expectedTotal
              : null,
          'questionCountMetricNote': 'Count agreement does not verify question identity, alternatives, images, or continuity.',
          'questionCountAgreementRate': expectedRecords.isEmpty
              ? null
              : documents
                        .where(
                          (document) =>
                              document['questionCountAgreement'] == true,
                        )
                        .length /
                    expectedRecords.length,
          'visualPreservationRate': null,
          'visualPreservationNote': 'No annotated visual-content reference is available; warning counts are not a preservation score.',
          'ocrEvaluated': false,
          'ocrEvaluationNote': 'This host benchmark runs the native-text path only; native OCR engines are not loaded by the Linux test runner.',
          'metadataMetrics': _metadataMetrics(documents),
          'processingMilliseconds': documents.fold<int>(
            0,
            (sum, document) =>
                sum + (document['processingMilliseconds']! as int),
          ),
        },
        'documents': documents,
        'answerKeys': answerKeys,
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

  final esaRoot = Directory('build/qa/military-exams');
  final esaYears = [2024, 2025, 2026];
  final esaFiles = [
    for (final year in esaYears)
      File(
        '${esaRoot.path}${Platform.pathSeparator}exercito'
        '${Platform.pathSeparator}esa-$year-prova-geral.pdf',
      ),
  ];
  test(
    'validates numbered questions and metadata in official ESA cadernos',
    skip: esaFiles.every((file) => file.existsSync())
        ? false
        : 'Download the official ESA PDFs with qa/update_corpus.py.',
    () async {
      final corpusManifest = jsonDecode(
        File('qa/corpus_manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final manifestDocuments = (corpusManifest['documents'] as List)
          .cast<Map<String, dynamic>>();
      final documentReports = <Map<String, Object?>>[];
      final metadataCounts = <String, Map<String, int>>{
        for (final field in const [
          'title',
          'board',
          'institution',
          'year',
          'category',
          'instance',
        ])
          field: {'correct': 0, 'incorrect': 0, 'abstained': 0},
      };

      for (final year in esaYears) {
        final id = 'esa-$year-geral';
        final manifestDocument = manifestDocuments.firstWhere(
          (document) => document['id'] == id,
        );
        final file = esaFiles[esaYears.indexOf(year)];
        final bytes = await file.readAsBytes();
        final documentSha256 = sha256.convert(bytes).toString();
        expect(documentSha256, manifestDocument['sha256']);

        final extraction = await const PdfTextExtractor().extract(
          bytes,
          sourceName: file.path,
        );
        final questions = const QuestionParser().parsePages(
          extraction.pages.map((page) => page.text).toList(growable: false),
        );
        final numberedQuestions = questions
            .where((question) => question.number != null)
            .toList(growable: false);
        expect(
          numberedQuestions.map((question) => question.number),
          List<int>.generate(50, (index) => index + 1),
          reason: '$id must preserve the official objective numbering 1–50.',
        );
        final unnumberedPrompts = questions
            .where((question) => question.number == null)
            .toList(growable: false);
        expect(unnumberedPrompts, hasLength(1), reason: id);
        expect(
          unnumberedPrompts.single.format,
          QuestionFormat.openEnded,
          reason: '$id must keep its unnumbered essay prompt separate.',
        );

        if (year == 2024) {
          final question23 = numberedQuestions[22];
          expect(question23.statement, contains('Caramuru'));
          expect(question23.options, [
            'Arcadismo.',
            'Simbolismo.',
            'Barroco.',
            'Realismo.',
            'Parnasianismo.',
          ]);
        }
        if (year == 2026) {
          expect(numberedQuestions[19].options, hasLength(5));
          expect(
            numberedQuestions[20].statement,
            contains('Com base no Texto VI'),
          );
        }

        final pages = extraction.pages
            .take(5)
            .map((page) => '${page.text}\n${page.nativeText}')
            .toList(growable: false);
        final suggestion = suggestExamMetadata(
          fileName: manifestDocument['path'] as String,
          firstPageText: pages.first,
          pages: pages,
        );
        final groundTruth =
            manifestDocument['metadataGroundTruth'] as Map<String, dynamic>;
        final actualMetadata = {
          'title': suggestion.title,
          'board': suggestion.board,
          'institution': suggestion.institution,
          'year': suggestion.year,
          'category': suggestion.category,
          'instance': suggestion.instance,
        };
        for (final field in metadataCounts.keys) {
          final expected = field == 'title'
              ? groundTruth['titleContains']
              : groundTruth[field];
          final actual = actualMetadata[field];
          final matches = field == 'title'
              ? actual is String &&
                    expected is String &&
                    actual.contains(expected)
              : actual == expected;
          if (matches && expected != null) {
            metadataCounts[field]!['correct'] =
                metadataCounts[field]!['correct']! + 1;
          } else if (actual == null) {
            metadataCounts[field]!['abstained'] =
                metadataCounts[field]!['abstained']! + 1;
          } else {
            metadataCounts[field]!['incorrect'] =
                metadataCounts[field]!['incorrect']! + 1;
          }
        }

        documentReports.add({
          'id': id,
          'sourceUrl': manifestDocument['downloadUrl'],
          'sha256': documentSha256,
          'pages': extraction.pageCount,
          'numberedObjectiveQuestions': numberedQuestions.length,
          'objectiveSequenceExact': true,
          'unnumberedOpenEndedPrompts': unnumberedPrompts.length,
          'questionsWithFiveAlternatives': numberedQuestions
              .where((question) => question.options.length == 5)
              .length,
          'questionsNeedingReview': questions
              .where(
                (question) =>
                    question.warning != null || question.confidence < .8,
              )
              .length,
          'metadata': {
            'suggested': actualMetadata,
            'groundTruth': groundTruth,
            'fieldsNeedingAttention': suggestion.fieldsNeedingAttention,
          },
        });
      }

      final metadataMetrics = {
        for (final entry in metadataCounts.entries)
          entry.key: {
            ...entry.value,
            'precision':
                entry.value['correct']! + entry.value['incorrect']! == 0
                ? null
                : entry.value['correct']! /
                      (entry.value['correct']! + entry.value['incorrect']!),
          },
      };
      final questionsWithFiveAlternatives = documentReports.fold<int>(
        0,
        (sum, document) =>
            sum + (document['questionsWithFiveAlternatives']! as int),
      );
      final report = {
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'method': 'Native-text PDF extraction; numbered sequence checked against official caderno labels.',
        'summary': {
          'officialDocumentsProcessed': documentReports.length,
          'numberedObjectiveQuestionsExpected': 150,
          'numberedObjectiveQuestionsRecovered': 150,
          'numberingSequenceExact': true,
          'questionsWithFiveAlternatives': questionsWithFiveAlternatives,
          'alternativeCountRate': questionsWithFiveAlternatives / 150,
          'unnumberedEssayPrompts': 3,
          'metadataMetrics': metadataMetrics,
          'visualPreservationRate': null,
          'visualPreservationNote': 'Image and formula fidelity requires manual page comparison; this report does not score it.',
          'ocrEvaluated': false,
        },
        'documents': documentReports,
      };
      final reportFile = File('build/qa/esa-corpus-benchmark.json');
      await reportFile.parent.create(recursive: true);
      await reportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
    },
  );
}

Map<String, Object?> _metadataMetrics(List<Map<String, Object?>> documents) {
  final byBoard = <String, List<Map<String, Object?>>>{};
  for (final document in documents) {
    final board = document['board']?.toString() ?? 'Não identificada';
    byBoard.putIfAbsent(board, () => []).add(document);
  }
  return {
    'overall': _scoreMetadata(documents),
    'byBoard': {
      for (final entry in byBoard.entries)
        entry.key: _scoreMetadata(entry.value),
    },
    'note': 'Positive and negative ground truth is included only when explicitly annotated in the corpus manifest; an unannotated field is not scored.',
  };
}

Map<String, Object?> _scoreMetadata(List<Map<String, Object?>> documents) {
  const fields = [
    'title',
    'board',
    'institution',
    'year',
    'category',
    'instance',
  ];
  final result = <String, Object?>{};
  for (final field in fields) {
    var positives = 0;
    var negatives = 0;
    var truePositive = 0;
    var falsePositive = 0;
    var falseNegative = 0;
    var trueNegative = 0;
    var negativeFalsePositive = 0;
    var abstained = 0;
    var identifiedPositive = 0;
    for (final document in documents) {
      final truth = document['metadataGroundTruth'];
      if (truth is! Map) continue;
      final truthKey = field == 'title' ? 'titleContains' : field;
      if (!truth.containsKey(truthKey)) continue;
      final expected = truth[truthKey];
      final metadata = document['metadata'];
      final suggested = metadata is Map ? metadata['suggested'] : null;
      final actual = suggested is Map ? suggested[field] : null;
      if (expected == null) {
        negatives++;
        if (actual == null) {
          trueNegative++;
        } else {
          falsePositive++;
          negativeFalsePositive++;
        }
        continue;
      }

      positives++;
      if (actual == null) {
        abstained++;
        falseNegative++;
        continue;
      }
      identifiedPositive++;
      final matches = field == 'title'
          ? _normalizeMetadata(actual.toString())
                .contains(_normalizeMetadata(expected.toString()))
          : _metadataValuesEqual(actual, expected);
      if (matches) {
        truePositive++;
      } else {
        falsePositive++;
        falseNegative++;
      }
    }
    result[field] = {
      'annotatedPositiveDocuments': positives,
      'annotatedNegativeDocuments': negatives,
      'truePositive': truePositive,
      'falsePositive': falsePositive,
      'falseNegative': falseNegative,
      'trueNegative': trueNegative,
      'abstainedOnPositive': abstained,
      'coverage': positives == 0 ? null : identifiedPositive / positives,
      'precision': truePositive + falsePositive == 0
          ? null
          : truePositive / (truePositive + falsePositive),
      'recall': positives == 0 ? null : truePositive / positives,
      'negativeFalsePositiveRate': negatives == 0
          ? null
          : negativeFalsePositive / negatives,
    };
  }
  return result;
}

bool _metadataValuesEqual(Object actual, Object expected) {
  if (actual is num && expected is num) {
    return actual == expected;
  }
  return _normalizeMetadata(actual.toString()) ==
      _normalizeMetadata(expected.toString());
}

String _normalizeMetadata(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

Future<Map<String, dynamic>?> _readPreviousReport(File reportFile) async {
  if (!await reportFile.exists()) return null;
  final decoded = jsonDecode(await reportFile.readAsString());
  return decoded is Map<String, dynamic> &&
          decoded['documents'] is List &&
          decoded['pipelineSha256'] is String
      ? decoded
      : null;
}

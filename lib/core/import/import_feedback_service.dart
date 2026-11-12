import 'dart:async';
import 'dart:convert';

import 'package:prova_social/core/backend/local_exam_store.dart';
import 'package:prova_social/core/import/feedback_queue.dart';
import 'package:prova_social/core/import/imported_document.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/question_parser.dart';

/// Serviço de feedback de importação.
class ImportFeedbackService {
  ImportFeedbackService({
    required this.queue,
    required this.examStore,
    this.isAuthenticated,
    this.onEventsReady,
  });

  final DiagnosticQueue queue;
  final LocalExamStore examStore;
  final bool Function()? isAuthenticated;
  final void Function(List<ImportDiagnosticEvent>)? onEventsReady;

  /// Registra conclusão de extração.
  Future<void> recordExtractionCompleted({
    required ImportedDocument document,
    required ImportQualityAssessment quality,
    required Duration processingTime,
    required int ocrPagesCount,
    required int nativeTextPagesCount,
  }) async {
    await queue.enqueue(ImportDiagnosticEvent(
      timestamp: DateTime.now(),
      eventType: ImportDiagnosticEventType.extractionCompleted,
      payload: {
        'documentId': document.id,
        'pageCount': document.pages.length,
        'questionCount': document.questions.length,
        'qualityState': quality.status.name,
        'questionsNeedingReview': quality.questionsNeedingReview,
        'processingTimeMs': processingTime.inMilliseconds,
        'ocrPagesCount': ocrPagesCount,
        'nativeTextPagesCount': nativeTextPagesCount,
        'questionsByFormat': _countByFormat(document.questions),
        'warnings': quality.reasons,
      },
    ));
  }

  /// Registra OCR concluído.
  Future<void> recordOcrCompleted({
    required int totalPages,
    required int ocrPages,
    required Duration ocrTime,
    required String engineUsed,
  }) async {
    await queue.enqueue(ImportDiagnosticEvent(
      timestamp: DateTime.now(),
      eventType: ImportDiagnosticEventType.ocrCompleted,
      payload: {
        'totalPages': totalPages,
        'ocrPages': ocrPages,
        'ocrTimeMs': ocrTime.inMilliseconds,
        'engine': engineUsed,
      },
    ));
  }

  /// Registra parsing concluído.
  Future<void> recordParsingCompleted({
    required List<ImportedQuestion> questions,
    required Duration parsingTime,
  }) async {
    await queue.enqueue(ImportDiagnosticEvent(
      timestamp: DateTime.now(),
      eventType: ImportDiagnosticEventType.parsingCompleted,
      payload: {
        'questionCount': questions.length,
        'parsingTimeMs': parsingTime.inMilliseconds,
        'questionsByFormat': _countByFormat(questions),
        'avgConfidence': questions.isEmpty
            ? 0
            : questions.map((q) => q.confidence).reduce((a, b) => a + b) / questions.length,
        'visualOptionsCount': questions.where((q) => q.hasVisualOptions).length,
      },
    ));
  }

  /// Registra quality gate avaliado.
  Future<void> recordQualityGateEvaluated({
    required ImportQualityAssessment quality,
  }) async {
    await queue.enqueue(ImportDiagnosticEvent(
      timestamp: DateTime.now(),
      eventType: ImportDiagnosticEventType.qualityGateEvaluated,
      payload: {
        'overallState': quality.status.name,
        'questionsNeedingReview': quality.questionsNeedingReview,
        'notices': quality.reasons,
        'feasibleCount': quality.duplicateQuestionCount,
        'fixableCount': quality.incompleteQuestionCount,
        'notFeasibleCount': quality.missingExpectedQuestionCount,
      },
    ));
  }

  /// Registra edição manual do usuário.
  Future<void> recordManualEdit({
    required String questionId,
    required String field,
    required String oldValue,
    required String newValue,
  }) async {
    await queue.enqueue(ImportDiagnosticEvent(
      timestamp: DateTime.now(),
      eventType: ImportDiagnosticEventType.manualEdit,
      payload: {
        'questionId': questionId,
        'field': field,
        'oldValueLength': oldValue.length,
        'newValueLength': newValue.length,
      },
    ));
  }

  /// Registra tentativa de publicação.
  Future<void> recordPublishAttempted({
    required String documentId,
    required bool success,
    String? error,
  }) async {
    await queue.enqueue(ImportDiagnosticEvent(
      timestamp: DateTime.now(),
      eventType: success
          ? ImportDiagnosticEventType.publishSucceeded
          : ImportDiagnosticEventType.publishFailed,
      payload: {
        'documentId': documentId,
        'success': success,
        'error': error,
      },
    ));
  }

  /// Solicita consentimento do usuário para envio de feedback.
  Future<bool> requestConsentAndExport() async {
    // Em produção, isso abriria um dialog/modal
    // Por enquanto, retorna false para não enviar automaticamente
    return false;
  }

  /// Exporta eventos consentidos para envio.
  Future<FeedbackExportResult> exportForSending() async {
    final events = await queue.getAllForExport();
    if (events.isEmpty) {
      return FeedbackExportResult.empty();
    }
    final payload = _buildExportPayload(events);
    return FeedbackExportResult(
      events: events,
      payload: payload,
      exportedAt: DateTime.now(),
    );
  }

  /// Confirma envio e limpa eventos exportados.
  Future<void> confirmSent(List<String> eventIds) async {
    await queue.clearExported(eventIds);
  }

  /// Limpeza periódica de eventos antigos.
  Future<void> pruneOldEvents() async {
    await queue.pruneOldEvents();
  }

  Map<String, int> _countByFormat(List<ImportedQuestion> questions) {
    final counts = <String, int>{};
    for (final q in questions) {
      counts[q.format.name] = (counts[q.format.name] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, Object?> _buildExportPayload(List<ImportDiagnosticEvent> events) {
    return {
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'eventCount': events.length,
      'events': events.map((e) => e.toJson()).toList(),
    };
  }
}

/// Resultado de exportação de feedback.
class FeedbackExportResult {
  const FeedbackExportResult({
    required this.events,
    required this.payload,
    required this.exportedAt,
  });

  factory FeedbackExportResult.empty() => FeedbackExportResult(
    events: const [],
    payload: const {},
    exportedAt: DateTime.now(),
  );

  final List<ImportDiagnosticEvent> events;
  final Map<String, Object?> payload;
  final DateTime exportedAt;

  bool get isEmpty => events.isEmpty;

  String toJsonString() => jsonEncode(payload);
}
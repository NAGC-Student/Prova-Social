import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Evento de diagnóstico de importação para fila de feedback.
class ImportDiagnosticEvent {
  ImportDiagnosticEvent({
    required this.timestamp,
    required this.eventType,
    required this.payload,
    this.consentGiven = false,
    this.userId,
  });

  final DateTime timestamp;
  final ImportDiagnosticEventType eventType;
  final Map<String, Object?> payload;
  final bool consentGiven;
  final String? userId;

  String get id => sha256.convert(utf8.encode(
    '$timestamp$eventType${jsonEncode(payload)}',
  )).toString().substring(0, 16);

  Map<String, Object?> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'eventType': eventType.name,
    'payload': payload,
    'consentGiven': consentGiven,
    'userId': userId,
  };

  factory ImportDiagnosticEvent.fromJson(Map<String, dynamic> json) =>
      ImportDiagnosticEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventType: ImportDiagnosticEventType.values.firstWhere(
          (e) => e.name == json['eventType'],
          orElse: () => ImportDiagnosticEventType.other,
        ),
        payload: Map<String, Object?>.from(json['payload'] as Map),
        consentGiven: json['consentGiven'] as bool? ?? false,
        userId: json['userId'] as String?,
      );
}

/// Tipos de eventos de diagnóstico.
enum ImportDiagnosticEventType {
  /// Extração de PDF concluída.
  extractionCompleted,
  /// OCR processado.
  ocrCompleted,
  /// Parser finalizado.
  parsingCompleted,
  /// Quality gate avaliado.
  qualityGateEvaluated,
  /// Questão marcada pelo usuário.
  questionFlagged,
  /// Edição manual feita pelo usuário.
  manualEdit,
  /// Publicação tentada.
  publishAttempted,
  /// Publicação bem-sucedida.
  publishSucceeded,
  /// Publicação falhou.
  publishFailed,
  /// Outro evento.
  other,
}

/// Fila local de eventos de diagnóstico para feedback.
class DiagnosticQueue {
  DiagnosticQueue({required this.storage});

  final DiagnosticQueueStorage storage;
  static const _key = 'import_diagnostic_queue_v1';

  /// Adiciona evento à fila.
  Future<void> enqueue(ImportDiagnosticEvent event) async {
    final queue = await _load();
    queue.add(event);
    await _save(queue);
  }

  /// Obtém eventos pendentes de consentimento.
  Future<List<ImportDiagnosticEvent>> getPendingConsent() async {
    final queue = await _load();
    return queue.where((e) => !e.consentGiven).toList(growable: false);
  }

  /// Marca eventos como tendo consentimento.
  Future<void> markConsentGiven(List<String> eventIds) async {
    final queue = await _load();
    for (final event in queue) {
      if (eventIds.contains(event.id)) {
        // Cria novo evento com consentGiven = true
        final index = queue.indexOf(event);
        queue[index] = ImportDiagnosticEvent(
          timestamp: event.timestamp,
          eventType: event.eventType,
          payload: event.payload,
          consentGiven: true,
          userId: event.userId,
        );
      }
    }
    await _save(queue);
  }

  /// Remove eventos antigos (mais de 30 dias).
  Future<void> pruneOldEvents() async {
    final queue = await _load();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final pruned = queue.where((e) => e.timestamp.isAfter(cutoff)).toList(growable: false);
    await _save(pruned);
  }

  /// Obtém todos os eventos para envio.
  Future<List<ImportDiagnosticEvent>> getAllForExport() async {
    final queue = await _load();
    return queue.where((e) => e.consentGiven).toList(growable: false);
  }

  /// Limpa eventos já exportados.
  Future<void> clearExported(List<String> exportedIds) async {
    final queue = await _load();
    queue.removeWhere((e) => exportedIds.contains(e.id));
    await _save(queue);
  }

  Future<List<ImportDiagnosticEvent>> _load() async {
    final raw = await storage.read(_key);
    if (raw == null) return [];
    final json = jsonDecode(raw) as List;
    return json
        .map((e) => ImportDiagnosticEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<void> _save(List<ImportDiagnosticEvent> queue) async {
    final json = queue.map((e) => e.toJson()).toList();
    await storage.write(_key, jsonEncode(json));
  }
}

/// Storage para fila de diagnóstico.
abstract class DiagnosticQueueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Implementação em memória para testes.
class InMemoryDiagnosticQueueStorage implements DiagnosticQueueStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
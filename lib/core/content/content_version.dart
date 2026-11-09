import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/models/exam.dart';
import '../import/question_parser.dart';

/// Identidade canônica da revisão de conteúdo de uma prova.
///
/// O hash cobre a posição, o enunciado, as alternativas, o gabarito, o tópico
/// e, para questões importadas, o formato. Resposta esperada e rubrica entram
/// aqui quando o modelo de questão discursiva existir (ADR-0002, etapa 2).
///
/// A posição faz parte do hash porque as respostas do rascunho são posicionais:
/// reordenar questões invalida a tentativa mesmo que o conjunto seja o mesmo.
abstract final class ContentVersion {
  static String ofQuestions(List<Question> questions) => _digest([
    for (var position = 0; position < questions.length; position++)
      {
        'position': position,
        'statement': questions[position].statement.trim(),
        'options': [
          for (final option in questions[position].options) option.trim(),
        ],
        'correctIndex': questions[position].correctIndex,
        'topic': _normalizeTopic(questions[position].topic),
      },
  ]);

  static String ofImportedQuestions(List<ImportedQuestion> questions) =>
      _digest([
        for (var position = 0; position < questions.length; position++)
          {
            'position': position,
            'statement': questions[position].statement.trim(),
            'options': [
              for (final option in questions[position].options) option.trim(),
            ],
            'correctIndex': questions[position].correctIndex,
            'topic': _normalizeTopic(questions[position].topic),
            'format': questions[position].format.name,
          },
      ]);

  static String _digest(List<Map<String, Object?>> payload) =>
      sha256.convert(utf8.encode(jsonEncode(payload))).toString();

  static String _normalizeTopic(String? topic) {
    final normalized = topic?.trim() ?? '';
    return normalized.isEmpty ? 'Geral' : normalized;
  }
}

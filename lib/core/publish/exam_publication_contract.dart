import 'dart:convert';

import '../import/question_parser.dart';

/// Contrato único de publicação usado pela tela e pelo serviço.
///
/// A tela não pode aceitar algo que o serviço recusa, nem o contrário.
abstract final class ExamPublicationContract {
  static const maxQuestions = 300;
  static const maxPayloadBytes = 8 * 1024 * 1024;

  static String normalizeTopic(String? topic) {
    final normalized = topic?.trim() ?? '';
    if (normalized.isEmpty) return 'Geral';
    return normalized.length <= 100 ? normalized : normalized.substring(0, 100);
  }

  static String? metadataError({
    required String title,
    required String category,
    required String source,
    required int durationMinutes,
    int? year,
    String? sourceUrl,
    String? board,
    String? institution,
    String? instance,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.length < 3 || normalizedTitle.length > 180) {
      return 'O título precisa ter entre 3 e 180 caracteres.';
    }
    final normalizedCategory = category.trim();
    if (normalizedCategory.length < 2 || normalizedCategory.length > 80) {
      return 'A categoria precisa ter entre 2 e 80 caracteres.';
    }
    final normalizedSource = source.trim();
    if (normalizedSource.length < 2 || normalizedSource.length > 160) {
      return 'A fonte precisa ter entre 2 e 160 caracteres.';
    }
    if (durationMinutes < 1 || durationMinutes > 1440) {
      return 'A duração precisa estar entre 1 e 1440 minutos.';
    }
    if (year != null && (year < 1900 || year > 2200)) {
      return 'O ano precisa estar entre 1900 e 2200.';
    }
    if ((board?.trim().length ?? 0) > 120) {
      return 'A banca pode ter no máximo 120 caracteres.';
    }
    if ((institution?.trim().length ?? 0) > 180) {
      return 'A instituição pode ter no máximo 180 caracteres.';
    }
    if ((instance?.trim().length ?? 0) > 120) {
      return 'A etapa ou caderno pode ter no máximo 120 caracteres.';
    }
    try {
      normalizeSourceUrl(sourceUrl);
    } on FormatException catch (error) {
      return error.message;
    }
    return null;
  }

  static String? questionsError(
    List<ImportedQuestion> questions, {
    required bool allowOpenEnded,
  }) {
    if (questions.isEmpty) {
      return 'Adicione pelo menos uma questão.';
    }
    if (questions.length > maxQuestions) {
      return 'Uma prova pode ter no máximo $maxQuestions questões.';
    }

    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      final position = index + 1;
      if (question.format == QuestionFormat.unknown) {
        return 'A questão $position tem formato desconhecido e não pode ser publicada.';
      }
      if (question.format == QuestionFormat.openEnded && !allowOpenEnded) {
        return 'A questão $position é discursiva. A publicação de discursivas ainda não está disponível.';
      }
      final statement = question.statement.trim();
      if (statement.length < 2 || statement.length > 20000) {
        return 'A questão $position precisa de um enunciado entre 2 e 20.000 caracteres.';
      }
      if (question.format != QuestionFormat.openEnded) {
        if (question.options.length < 2 || question.options.length > 8) {
          return 'A questão $position precisa ter entre 2 e 8 alternativas.';
        }
        for (
          var optionIndex = 0;
          optionIndex < question.options.length;
          optionIndex++
        ) {
          final option = question.options[optionIndex];
          final normalized = option.trim();
          final hasImage =
              question.optionImageBase64.containsKey(optionIndex) ||
              question.hasVisualOptions;
          if ((normalized.isEmpty && !hasImage) || normalized.length > 4000) {
            return 'A questão $position tem alternativa vazia ou acima de 4.000 caracteres.';
          }
        }
        final correctIndex = question.correctIndex;
        if (correctIndex == null ||
            correctIndex < 0 ||
            correctIndex >= question.options.length) {
          return 'A questão $position precisa de um gabarito válido.';
        }
      }
      if (question.reviewState != QuestionReviewState.reviewed) {
        return 'A questão $position ainda não foi revisada.';
      }
    }

    final payload = questionPayload(
      questions,
      includeOpenEnded: allowOpenEnded,
    );
    if (utf8.encode(jsonEncode(payload)).length > maxPayloadBytes) {
      return 'O conteúdo excede o limite de 8 MB.';
    }
    return null;
  }

  static List<Map<String, Object?>> questionPayload(
    List<ImportedQuestion> questions, {
    required bool includeOpenEnded,
  }) {
    return [
      for (final question in questions)
        if (includeOpenEnded || question.format != QuestionFormat.openEnded)
          <String, Object?>{
            'topic': normalizeTopic(question.topic),
            'statement': question.statement.trim(),
            'options': question.options
                .asMap()
                .entries
                .map(
                  (entry) => entry.value.trim().isNotEmpty
                      ? entry.value.trim()
                      : 'Alternativa ${String.fromCharCode(65 + entry.key)} (imagem)',
                )
                .toList(growable: false),
            'correct_index': question.correctIndex,
            'question_type': question.format == QuestionFormat.openEnded
                ? 'discursive'
                : 'objective',
            'explanation': question.explanation?.trim(),
            'expected_answer': question.expectedAnswer?.trim(),
            'rubric': question.rubric?.trim(),
            'canonical_url': question.canonicalUrl?.trim(),
            'source': question.source?.trim(),
            'version': question.version,
            'content_hash': question.contentHash,
          },
    ];
  }

  static bool isValidSourceUrl(String? value) {
    try {
      normalizeSourceUrl(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  static String? normalizeSourceUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final uri = Uri.tryParse(normalized);
    if (normalized.length > 500 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'O link da fonte precisa ser uma URL HTTPS válida.',
      );
    }
    return normalized;
  }
}

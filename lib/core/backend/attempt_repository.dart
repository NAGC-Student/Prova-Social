import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';
import 'attempt_submission.dart';

class AttemptRepository implements AttemptSubmitter {
  AttemptRepository({SupabaseClient? client, this.isAuthenticated})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  final bool Function()? isAuthenticated;

  @override
  Future<ExamResult> submit(AttemptSubmission submission) async {
    final exam = submission.exam;
    if (exam.isLocal) {
      throw StateError('Provas locais não podem ser enviadas ao servidor.');
    }
    final authenticated =
        isAuthenticated?.call() ?? _client.auth.currentUser != null;
    if (!authenticated) {
      throw const AttemptSubmissionException(
        message: 'Entre na sua conta para sincronizar a entrega.',
        transient: false,
        requiresAuthentication: true,
      );
    }
    final payload = <String, int>{};
    for (final entry in submission.answers.entries) {
      if (entry.key.isNotEmpty) {
        payload[entry.key] = entry.value;
      }
    }
    final reviewIds = submission.markedForReview
        .where((id) => id.isNotEmpty)
        .toList();
    try {
      final response = await _client
          .rpc<Map<String, dynamic>>(
            'submit_exam_attempt',
            params: {
              'p_exam_id': exam.id,
              'p_answers': payload,
              'p_review_question_ids': reviewIds,
              'p_duration_seconds': submission.durationSeconds,
              'p_client_attempt_id': submission.clientAttemptId,
            },
          )
          .timeout(const Duration(seconds: 15));
      final rawReview = List<Map<String, dynamic>>.from(
        response['review'] as List<dynamic>? ?? const [],
      );
      final keys = <String, int>{
        for (final item in rawReview)
          item['question_id'] as String: item['correct_index'] as int,
      };
      final selectedById = <String, int>{
        for (final item in rawReview)
          if (item['selected_index'] case final int selected)
            item['question_id'] as String: selected,
      };
      final reviewIdsResult = <String>{
        for (final item in rawReview)
          if (item['marked_for_review'] == true) item['question_id'] as String,
      };
      final correctedQuestions = exam.questions
          .map((question) => question.copyWith(correctIndex: keys[question.id]))
          .toList(growable: false);
      // O banco de dados valida correct_index entre 0 e 7, mas não cruza com o
      // tamanho de alternatives da questão. Um gabarito fora do intervalo
      // invalida a entrega inteira em vez de armazenar um gabarito impossível.
      for (final question in correctedQuestions) {
        if (question.correctIndex != null &&
            (question.correctIndex! < 0 ||
                question.correctIndex! >= question.options.length)) {
          throw AttemptSubmissionException(
            message:
                'O servidor devolveu um gabarito fora do intervalo para a questão ${question.id}; a entrega foi recusada.',
            transient: false,
          );
        }
      }
      final answers = <String, int>{};
      for (final entry in selectedById.entries) {
        answers[entry.key] = entry.value;
      }
      return ExamResult(
        exam: exam.copyWith(questions: correctedQuestions),
        examVersionId: exam.currentVersion?.id ?? '',
        answers: answers,
        markedForReview: reviewIdsResult,
        durationSeconds: submission.durationSeconds,
        finishedAt: submission.finishedAt,
      );
    } on AttemptSubmissionException {
      rethrow;
    } on AuthException catch (error) {
      throw AttemptSubmissionException(
        message: error.message,
        transient: false,
        cause: error,
      );
    } on PostgrestException catch (error) {
      final code = error.code ?? '';
      final transient =
          code.startsWith('08') ||
          code.startsWith('40') ||
          code.startsWith('53') ||
          code.startsWith('57') ||
          code.startsWith('58') ||
          code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003' ||
          code == 'PGRST202';
      throw AttemptSubmissionException(
        message: code == 'PGRST202'
            ? 'O serviço de correção precisa ser atualizado. '
                  'Sua entrega continua salva no aparelho.'
            : error.message,
        transient: transient,
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw AttemptSubmissionException(
        message: 'Tempo limite ao enviar a entrega.',
        transient: true,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AttemptSubmissionException(
        message: 'Sem conexão com o servidor.',
        transient: true,
        cause: error,
      );
    } catch (error) {
      throw AttemptSubmissionException(
        message: 'Falha desconhecida ao enviar a entrega.',
        transient: false,
        cause: error,
      );
    }
  }
}
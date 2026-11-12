import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prova_social/core/backend/attempt_repository.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  test('visitante mantém a entrega local e não chama a RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.test',
      'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      AttemptRepository(client: client).submit(testSubmission()),
      throwsA(
        isA<AttemptSubmissionException>()
            .having(
              (error) => error.requiresAuthentication,
              'login exigido',
              true,
            )
            .having((error) => error.transient, 'não é falha de rede', false),
      ),
    );
    expect(requests, isEmpty);
  });

  test(
    'conta autenticada aceita correção completa correspondente à entrega',
    () async {
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'total': 1,
              'correct': 1,
              'review': [
                {
                  'question_id': 'q1',
                  'correct_index': 1,
                  'selected_index': 1,
                  'marked_for_review': false,
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final result = await AttemptRepository(
        client: client,
        isAuthenticated: () => true,
      ).submit(testSubmission());
      expect(result.correct, 1);
      expect(result.answers, {'q1': 1});
      expect(result.markedForReview, isEmpty);
    },
  );

  for (final code in ['PGRST202', '22023', '42501']) {
    test('classifica $code preservando a chamada idempotente', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'code': code, 'message': 'RPC recusada'}),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      const exam = Exam(
        id: 'exam',
        category: 'Geral',
        title: 'Prova',
        description: '',
        author: 'Fonte',
        durationMinutes: 30,
        attempts: 0,
        questions: [
          Question(
            id: 'q1',
            topic: 'Geral',
            statement: 'Q?',
            options: ['A', 'B'],
          ),
        ],
      );
      await expectLater(
        AttemptRepository(client: client, isAuthenticated: () => true).submit(
          AttemptSubmission(
            clientAttemptId: '11111111-1111-4111-8111-111111111111',
            exam: exam,
            answers: const {'q1': 1},
            markedForReview: const {},
            durationSeconds: 10,
            finishedAt: DateTime.utc(2026, 9, 26),
          ),
        ),
        throwsA(
          isA<AttemptSubmissionException>().having(
            (error) => error.transient,
            'pode tentar novamente após atualização do serviço',
            code == 'PGRST202',
          ),
        ),
      );
      expect(requests, hasLength(1));
      expect(
        (jsonDecode(requests.single.body) as Map)['p_client_attempt_id'],
        '11111111-1111-4111-8111-111111111111',
      );
    });
  }
}

AttemptSubmission testSubmission() => AttemptSubmission(
  clientAttemptId: '11111111-1111-4111-8111-111111111111',
  exam: const Exam(
    id: 'exam',
    category: 'Geral',
    title: 'Prova',
    description: '',
    author: 'Fonte',
    durationMinutes: 30,
    attempts: 0,
    questions: [
      Question(id: 'q1', topic: 'Geral', statement: 'Q?', options: ['A', 'B']),
    ],
  ),
  answers: const {'q1': 1},
  markedForReview: const {},
  durationSeconds: 10,
  finishedAt: DateTime.utc(2026, 9, 26),
);
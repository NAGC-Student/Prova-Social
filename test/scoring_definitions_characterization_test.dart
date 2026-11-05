import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prova_social/core/backend/attempt_repository.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/result/result_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Caracterização do estado de 05a8fc1: as expectativas abaixo descrevem o que o
// código faz, inclusive onde as definições de pontuação se contradizem. Trocar
// um número aqui para "consertar" a contradição é decisão de produto (ADR-0002
// e ADR-0006), não manutenção de teste.
void main() {
  const cincoQuestoes = Exam(
    id: 'exam-divergente',
    category: 'Geral',
    title: 'Prova com definições divergentes',
    description: '',
    author: 'Fonte',
    durationMinutes: 60,
    attempts: 0,
    questions: [
      Question(
        id: 'q0',
        topic: 'Álgebra',
        statement: 'gabarito válido, resposta certa',
        options: ['A', 'B'],
        correctIndex: 1,
      ),
      Question(
        id: 'q1',
        topic: 'Álgebra',
        statement: 'gabarito válido, resposta errada',
        options: ['A', 'B'],
        correctIndex: 0,
      ),
      Question(
        id: 'q2',
        topic: 'Geometria',
        statement: 'sem gabarito, em branco',
        options: ['A', 'B', 'C'],
      ),
      Question(
        id: 'q3',
        topic: 'Geometria',
        statement: 'gabarito fora do intervalo das alternativas',
        options: ['A', 'B'],
        correctIndex: 5,
      ),
      Question(
        id: 'q4',
        topic: '   ',
        statement: 'tópico vazio, em branco',
        options: ['A', 'B'],
        correctIndex: 0,
      ),
    ],
  );

  final tentativa = ExamResult(
    exam: cincoQuestoes,
    answers: const {0: 1, 1: 1, 3: 5},
    markedForReview: const {1},
    durationSeconds: 90,
    finishedAt: DateTime.utc(2026, 11, 5),
  );

  group('cinco definições de pontuação sobre a mesma tentativa', () {
    test('correct ignora se o gabarito cabe nas alternativas', () {
      expect(tentativa.correct, 2);
      expect(tentativa.wrongQuestionIndices, [1]);
    });

    test('correctableCount exige gabarito dentro do intervalo', () {
      expect(tentativa.correctableCount, 3);
    });

    test('scorePercent usa correctableCount, não o total de questões', () {
      expect(tentativa.scorePercent, 67);
    });

    test('byTopic tem o próprio denominador e descarta tópico vazio', () {
      expect(tentativa.byTopic, {
        'Álgebra': (correct: 1, total: 2),
        'Geometria': (correct: 1, total: 1),
      });
      final somaDosTopicos = tentativa.byTopic.values
          .map((entry) => entry.total)
          .fold<int>(0, (sum, total) => sum + total);
      expect(somaDosTopicos, isNot(cincoQuestoes.questions.length));
    });

    test('unanswered e o total do JSON são outras duas contagens', () {
      expect(tentativa.unanswered, 2);
      final json = tentativa.toJson();
      expect(json['total'], 5);
      expect(json['correct'], 2);
      expect((json['answers'] as List).first['question'], 1);
    });
  });

  test('gabarito fora do intervalo pode estourar os 100%', () {
    final resultado = ExamResult(
      exam: const Exam(
        id: 'exam-estouro',
        category: 'Geral',
        title: 'Prova',
        description: '',
        author: 'Fonte',
        durationMinutes: 30,
        attempts: 0,
        questions: [
          Question(
            id: 'q0',
            topic: 'Geral',
            statement: 'certa',
            options: ['A', 'B'],
            correctIndex: 1,
          ),
          Question(
            id: 'q1',
            topic: 'Geral',
            statement: 'certa',
            options: ['A', 'B'],
            correctIndex: 0,
          ),
          Question(
            id: 'q2',
            topic: 'Geral',
            statement: 'gabarito 5 em duas alternativas',
            options: ['A', 'B'],
            correctIndex: 5,
          ),
        ],
      ),
      answers: const {0: 1, 1: 0, 2: 5},
      markedForReview: const {},
      durationSeconds: 30,
      finishedAt: DateTime.utc(2026, 11, 5),
    );

    expect(resultado.correct, 3);
    expect(resultado.correctableCount, 2);
    expect(resultado.scorePercent, 150);
  });

  testWidgets('a tela mostra as quatro contagens ao mesmo tempo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage(result: tentativa, syncService: _filaDeTeste()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('67%'), findsOneWidget);
    expect(find.text('2 de 3 questões corrigíveis'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Revisar'), findsOneWidget);
    // Revisar é perguntas - corretas (result_page.dart:280): 5 - 2 = 3, e conta
    // as duas em branco e o gabarito inválido como se fossem respostas erradas.
    // Na mesma tela o botão de refazer diz "1 questão errada".
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Refazer 1 questão errada'), findsOneWidget);
  });

  testWidgets('branco é apresentado como revisão, nunca como erro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final tudoEmBranco = ExamResult(
      exam: cincoQuestoes,
      answers: const {},
      markedForReview: const {},
      durationSeconds: 120,
      finishedAt: DateTime.utc(2026, 11, 5),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage(result: tudoEmBranco, syncService: _filaDeTeste()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tudoEmBranco.correct, 0);
    expect(tudoEmBranco.wrongQuestionIndices, isEmpty);
    expect(tudoEmBranco.wrongQuestionsExam, isNull);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('Refazer'), findsNothing);
  });

  group('a entrega remota descarta o número calculado no servidor', () {
    test('o score_percent da RPC não chega ao resultado', () async {
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'total': 2,
              'correct': 1,
              'score_percent': 42,
              'review': [
                {
                  'question_id': 'q0',
                  'correct_index': 1,
                  'selected_index': 1,
                  'marked_for_review': false,
                },
                {
                  'question_id': 'q1',
                  'correct_index': 0,
                  'selected_index': null,
                  'marked_for_review': false,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);

      final resultado =
          await AttemptRepository(
            client: client,
            isAuthenticated: () => true,
          ).submit(
            AttemptSubmission(
              clientAttemptId: '22222222-2222-4222-8222-222222222222',
              exam: const Exam(
                id: 'exam',
                category: 'Geral',
                title: 'Prova',
                description: '',
                author: 'Fonte',
                durationMinutes: 30,
                attempts: 0,
                questions: [
                  Question(
                    id: 'q0',
                    topic: 'Geral',
                    statement: 'Q0',
                    options: ['A', 'B'],
                  ),
                  Question(
                    id: 'q1',
                    topic: 'Geral',
                    statement: 'Q1',
                    options: ['A', 'B'],
                  ),
                ],
              ),
              answers: const {0: 1},
              markedForReview: const {},
              durationSeconds: 10,
              finishedAt: DateTime.utc(2026, 11, 5),
            ),
          );

      expect(resultado.correct, 1);
      expect(resultado.correctableCount, 2);
      expect(resultado.scorePercent, 50);
      expect(resultado.scorePercent, isNot(42));
    });

    test(
      'gabarito do servidor fora do intervalo recusa a entrega inteira',
      () async {
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'total': 1,
                'correct': 1,
                'score_percent': 100,
                'review': [
                  {
                    'question_id': 'q0',
                    'correct_index': 5,
                    'selected_index': 5,
                    'marked_for_review': false,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        );
        addTearDown(client.dispose);

        // O CHECK do banco é `correct_index between 0 and 7` e não cruza com o
        // tamanho de `options`, então o servidor pode devolver esse gabarito; a
        // validação de attempt_repository.dart:84-86 transforma isso em recusa.
        await expectLater(
          AttemptRepository(client: client, isAuthenticated: () => true).submit(
            AttemptSubmission(
              clientAttemptId: '33333333-3333-4333-8333-333333333333',
              exam: const Exam(
                id: 'exam',
                category: 'Geral',
                title: 'Prova',
                description: '',
                author: 'Fonte',
                durationMinutes: 30,
                attempts: 0,
                questions: [
                  Question(
                    id: 'q0',
                    topic: 'Geral',
                    statement: 'Q0',
                    options: ['A', 'B'],
                  ),
                ],
              ),
              answers: const {0: 5},
              markedForReview: const {},
              durationSeconds: 10,
              finishedAt: DateTime.utc(2026, 11, 5),
            ),
          ),
          throwsA(isA<AttemptSubmissionException>()),
        );
      },
    );
  });
}

AttemptSyncService _filaDeTeste() =>
    AttemptSyncService(store: AttemptQueueStore(storage: _Memoria()));

class _Memoria implements AttemptQueueStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

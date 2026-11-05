import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prova_social/core/backend/exam_publication_service.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Caracterização do estado de 05a8fc1: estas expectativas registram o que a
// publicação faz, inclusive o que ela descarta. Preservar ou mudar cada item é
// decisão das ADRs 0002, 0006 e 0007, não ajuste de teste.
final requests = <http.Request>[];

final _user = {
  'id': '00000000-0000-4000-8000-000000000001',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'test@example.test',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': {'display_name': 'Pessoa Teste'},
};

Map<String, dynamic> _ultimaRpc(String caminho) {
  final request = requests.lastWhere(
    (entry) => entry.url.path.contains('/rpc/$caminho'),
    orElse: () => throw StateError('nenhuma chamada para $caminho'),
  );
  return Map<String, dynamic>.from(jsonDecode(request.body) as Map);
}

ImportedQuestion _importada({
  String topic = 'História',
  List<String> options = const ['A', 'B'],
  int? correctIndex = 1,
  QuestionFormat format = QuestionFormat.multipleChoice,
}) => ImportedQuestion(
  statement: 'Enunciado da questão?',
  options: options,
  correctIndex: correctIndex,
  topic: topic,
  format: format,
);

Future<String> _publicar({
  List<ImportedQuestion>? questions,
  String? sourceUrl,
}) => ExamPublicationService(client: Supabase.instance.client).publish(
  title: 'Prova caracterizada',
  category: 'Matemática',
  source: 'Instituição',
  durationMinutes: 30,
  questions: questions ?? [_importada()],
  sourceUrl: sourceUrl,
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 200, request: request);
        }
        if (request.url.path.endsWith('/user')) {
          return http.Response(jsonEncode(_user), 200, request: request);
        }
        if (request.url.path.contains('/rpc/')) {
          return http.Response(
            jsonEncode('exam-publicado'),
            200,
            request: request,
          );
        }
        return http.Response('[]', 200, request: request);
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'user': _user,
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() => requests.clear());

  group('fronteira de validação da publicação', () {
    test(
      'questão aberta aceita pelo parser é rejeitada antes de qualquer RPC',
      () async {
        // O parser conhece QuestionFormat.openEnded
        // (question_parser.dart:28) e a publicaão não tem como expressá-la:
        // exige 2..8 alternativas e gabarito (exam_publication_service.dart:45-58).
        final aberta = _importada(
          options: const [],
          correctIndex: null,
          format: QuestionFormat.openEnded,
        );
        expect(aberta.format, QuestionFormat.openEnded);
        await expectLater(
          _publicar(questions: [aberta]),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'mensagem atual',
              'Revise todas as questões e o gabarito.',
            ),
          ),
        );
        expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
      },
    );

    test('questão sem gabarito reprova a prova inteira', () async {
      await expectLater(
        _publicar(
          questions: [
            _importada(),
            _importada(correctIndex: null),
            _importada(topic: 'Geografia'),
          ],
        ),
        throwsFormatException,
      );
      expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
    });

    test('nove alternativas é a mesma recusa de uma alternativa', () async {
      for (final options in [
        const ['A'],
        const ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'],
      ]) {
        await expectLater(
          _publicar(questions: [_importada(options: options)]),
          throwsFormatException,
        );
      }
      expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
    });
  });

  group('o que o corpo publicado preserva e descarta', () {
    test('o tópico importado é substituído por Geral', () async {
      await _publicar(
        questions: [
          _importada(topic: 'História'),
          _importada(topic: 'Álgebra'),
        ],
      );
      final payload = (_ultimaRpc('publish_exam')['p_questions'] as List)
          .cast<Map>();
      expect(payload.map((q) => q['topic']), ['Geral', 'Geral']);
    });

    test('o tipo de origem publicado é sempre community', () async {
      await _publicar();
      expect(_ultimaRpc('publish_exam')['p_source_type'], 'community');
    });

    test('o gabarito sai no corpo da RPC relacional', () async {
      await _publicar();
      final payload = (_ultimaRpc('publish_exam')['p_questions'] as List)
          .cast<Map>();
      expect(payload.single['correct_index'], 1);
      expect(payload.single.containsKey('id'), isFalse);
      expect(payload.single.containsKey('format'), isFalse);
      expect(payload.single.containsKey('confidence'), isFalse);
    });

    test(
      'a presença de URL de origem troca a RPC, sem mudar o resto',
      () async {
        await _publicar();
        expect(
          requests.lastWhere((r) => r.url.path.contains('/rpc/')).url.path,
          '/rest/v1/rpc/publish_exam',
        );
        await _publicar(sourceUrl: 'https://prova.example.org/2024');
        expect(
          requests.lastWhere((r) => r.url.path.contains('/rpc/')).url.path,
          '/rest/v1/rpc/publish_exam_with_source_url',
        );
      },
    );

    test('a prova é devolvida como publicada mesmo sem pacote digital', () async {
      // O mock responde [] ao select de questions, então o índice do pacote não
      // bate (exam_publication_service.dart:170-171) e o erro é engolido em
      // :195-197. A publicação relacional já aconteceu.
      final examId = await _publicar();
      expect(examId, 'exam-publicado');
      expect(requests.where((r) => r.url.path.contains('/rpc/')), hasLength(1));
      expect(
        requests.where((r) => r.url.path.endsWith('/questions')),
        isNotEmpty,
      );
    });
  });
}

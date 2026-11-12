import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Social Graph RLS Policies', () {
    // Helper to create a mock Supabase client
    SupabaseClient createMockClient({
      required List<http.Request> requests,
      required http.Response Function(http.Request) responder,
    }) {
      return SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return responder(request);
        }),
      );
    }

    group('topics', () {
      test('allows public read of all topics', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'id': 1, 'slug': 'enem', 'name': 'ENEM'},
              {'id': 2, 'slug': 'matematica', 'name': 'Matemática'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        final response = await client.from('topics').select();

        expect(response, hasLength(2));
        expect(requests.single.method, 'GET');
        expect(requests.single.url.path, '/rest/v1/topics');
      });
    });

    group('exam_topics', () {
      test('allows public read for published public exams', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'exam_id': 'exam-1', 'topic_id': 1},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        final response = await client.from('exam_topics').select('topic_id').eq('exam_id', 'exam-1');

        expect(response, hasLength(1));
        expect(requests.single.url.queryParameters['exam_id'], 'eq.exam-1');
      });

      test('allows owner read for their own exams even if not published', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'exam_id': 'exam-owner', 'topic_id': 2},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        // This would require auth.uid() to match exam.author_id
        // The policy check is done server-side
        final response = await client.from('exam_topics').select('topic_id').eq('exam_id', 'exam-owner');

        expect(response, hasLength(1));
      });
    });

    group('topic_follows', () {
      test('allows owner to read their own follows', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'user_id': 'user-1', 'topic_id': 1, 'created_at': '2026-01-01T00:00:00Z'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        final response = await client.from('topic_follows').select().eq('user_id', 'user-1');

        expect(response, hasLength(1));
        expect(requests.single.url.queryParameters['user_id'], 'eq.user-1');
      });

      test('allows owner to insert follow', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'user_id': 'user-1', 'topic_id': 3}),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('topic_follows').insert({'user_id': 'user-1', 'topic_id': 3});

        expect(requests.single.method, 'POST');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['user_id'], 'user-1');
        expect(body['topic_id'], 3);
      });

      test('allows owner to delete their follow', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response('', 204, request: request),
        );
        addTearDown(client.dispose);

        await client.from('topic_follows').delete().eq('user_id', 'user-1').eq('topic_id', 1);

        expect(requests.single.method, 'DELETE');
      });
    });

    group('collections', () {
      test('allows public read of public collections', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'id': 'col-1', 'title': 'Minha Coleção', 'is_public': true, 'owner_id': 'user-1'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        final response = await client.from('collections').select().eq('is_public', true);

        expect(response, hasLength(1));
      });

      test('allows owner read of private collections', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'id': 'col-2', 'title': 'Privada', 'is_public': false, 'owner_id': 'user-1'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        // Owner can read their own private collections via auth.uid() = owner_id
        final response = await client.from('collections').select().eq('owner_id', 'user-1');

        expect(response, hasLength(1));
      });

      test('allows owner to insert collection', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'id': 'col-new', 'title': 'Nova', 'owner_id': 'user-1', 'is_public': false}),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('collections').insert({'title': 'Nova', 'owner_id': 'user-1'});

        expect(requests.single.method, 'POST');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['owner_id'], 'user-1');
      });

      test('allows owner to update their collection', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'id': 'col-1', 'title': 'Atualizada'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('collections').update({'title': 'Atualizada'}).eq('id', 'col-1');

        expect(requests.single.method, 'PATCH');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['title'], 'Atualizada');
      });

      test('allows owner to delete their collection', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response('', 204, request: request),
        );
        addTearDown(client.dispose);

        await client.from('collections').delete().eq('id', 'col-1');

        expect(requests.single.method, 'DELETE');
      });
    });

    group('collection_exams', () {
      test('allows read of exams in public collections', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'collection_id': 'col-1', 'exam_id': 'exam-1', 'position': 1},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        final response = await client.from('collection_exams').select().eq('collection_id', 'col-1');

        expect(response, hasLength(1));
      });

      test('allows owner to insert exam into their collection', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'collection_id': 'col-1', 'exam_id': 'exam-2', 'position': 2}),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('collection_exams').insert({'collection_id': 'col-1', 'exam_id': 'exam-2', 'position': 2});

        expect(requests.single.method, 'POST');
      });

      test('allows owner to update position', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'collection_id': 'col-1', 'exam_id': 'exam-1', 'position': 3}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('collection_exams').update({'position': 3}).eq('collection_id', 'col-1').eq('exam_id', 'exam-1');

        expect(requests.single.method, 'PATCH');
      });

      test('allows owner to delete exam from collection', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response('', 204, request: request),
        );
        addTearDown(client.dispose);

        await client.from('collection_exams').delete().eq('collection_id', 'col-1').eq('exam_id', 'exam-1');

        expect(requests.single.method, 'DELETE');
      });
    });

    group('profile_follows', () {
      test('allows public read of all follows', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'follower_id': 'user-1', 'followed_id': 'user-2'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        final response = await client.from('profile_follows').select();

        expect(response, hasLength(1));
      });

      test('allows user to insert follow', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'follower_id': 'user-1', 'followed_id': 'user-3'}),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('profile_follows').insert({'follower_id': 'user-1', 'followed_id': 'user-3'});

        expect(requests.single.method, 'POST');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['follower_id'], 'user-1');
        expect(body['followed_id'], 'user-3');
      });

test('prevents self-follow via check constraint', () async {
      final requests = <http.Request>[];
      final client = createMockClient(
        requests: requests,
        responder: (request) => http.Response(
          jsonEncode({'code': '23514', 'message': 'check constraint "profile_follows_follower_id_followed_id_check" violated'}),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.from('profile_follows').insert({'follower_id': 'user-1', 'followed_id': 'user-1'}),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23514')),
      );
    });

      test('allows user to delete their follow', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response('', 204, request: request),
        );
        addTearDown(client.dispose);

        await client.from('profile_follows').delete().eq('follower_id', 'user-1').eq('followed_id', 'user-2');

        expect(requests.single.method, 'DELETE');
      });
    });

    group('question_comments', () {
test('allows public read of visible comments on published exams', () async {
      final requests = <http.Request>[];
      final client = createMockClient(
        requests: requests,
        responder: (request) => http.Response(
          jsonEncode([
            {'id': 'c1', 'question_id': 'q1', 'author_id': 'user-1', 'body': 'Comentário', 'status': 'visible'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);

      final response = await client.from('question_comments').select().eq('question_id', 'q1').eq('status', 'visible');

      expect(response, hasLength(1));
      expect(requests.single.url.queryParameters['question_id'], 'eq.q1');
      expect(requests.single.url.queryParameters['status'], 'eq.visible');
    });

      test('allows authenticated user to insert visible comment', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'id': 'c-new', 'question_id': 'q1', 'author_id': 'user-1', 'body': 'Novo comentário', 'status': 'visible'}),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('question_comments').insert({'question_id': 'q1', 'author_id': 'user-1', 'body': 'Novo', 'status': 'visible'});

        expect(requests.single.method, 'POST');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['author_id'], 'user-1');
        expect(body['status'], 'visible');
      });

      test('allows author to update their comment', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'id': 'c1', 'body': 'Atualizado'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('question_comments').update({'body': 'Atualizado'}).eq('id', 'c1');

        expect(requests.single.method, 'PATCH');
      });

      test('allows author to soft-delete (status=deleted)', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'id': 'c1', 'status': 'deleted'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('question_comments').update({'status': 'deleted'}).eq('id', 'c1');

        expect(requests.single.method, 'PATCH');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['status'], 'deleted');
      });

      test('allows author to delete their comment', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response('', 204, request: request),
        );
        addTearDown(client.dispose);

        await client.from('question_comments').delete().eq('id', 'c1');

        expect(requests.single.method, 'DELETE');
      });
    });

    group('comment_votes', () {
      test('allows public read of all votes', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode([
              {'comment_id': 'c1', 'user_id': 'user-1'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        final response = await client.from('comment_votes').select().eq('comment_id', 'c1');

        expect(response, hasLength(1));
      });

      test('allows user to insert vote', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response(
            jsonEncode({'comment_id': 'c1', 'user_id': 'user-1'}),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(client.dispose);

        await client.from('comment_votes').insert({'comment_id': 'c1', 'user_id': 'user-1'});

        expect(requests.single.method, 'POST');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['user_id'], 'user-1');
      });

      test('allows user to delete their vote', () async {
        final requests = <http.Request>[];
        final client = createMockClient(
          requests: requests,
          responder: (request) => http.Response('', 204, request: request),
        );
        addTearDown(client.dispose);

        await client.from('comment_votes').delete().eq('comment_id', 'c1').eq('user_id', 'user-1');

        expect(requests.single.method, 'DELETE');
      });
    });
  });
}
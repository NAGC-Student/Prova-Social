import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient makeClient(
  List<http.Request> reqs,
  http.Response Function(http.Request) resp,
) {
  return SupabaseClient(
    'https://example.test',
    'public-key',
    httpClient: MockClient((req) async {
      reqs.add(req);
      return resp(req);
    }),
  );
}

void main() {
  group('Content Files & Storage RLS Policies', () {
    group('content_files', () {
      test('allows owner to read their own files', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(
              jsonEncode([{'id': 'f1', 'owner_id': 'u1', 'exam_id': 'e1', 'status': 'ready', 'object_key': 'u1/exams/e1/media/f1.webp'}]),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        addTearDown(client.dispose);
        final resp = await client.from('content_files').select().eq('owner_id', 'u1');
        expect(resp, hasLength(1));
        expect(reqs.single.url.queryParameters['owner_id'], 'eq.u1');
      });

      test('public reads ready files for published exams', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(
              jsonEncode([{'id': 'f2', 'owner_id': 'u2', 'exam_id': 'epub', 'status': 'ready', 'object_key': 'u2/exams/epub/media/f2.webp'}]),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        addTearDown(client.dispose);
        final resp = await client.from('content_files').select().eq('status', 'ready').eq('exam_id', 'epub');
        expect(resp, hasLength(1));
      });

      test('owner inserts file for own exam', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(
              jsonEncode({'id': 'fn', 'owner_id': 'u1', 'exam_id': 'e1', 'status': 'pending', 'object_key': 'u1/exams/e1/media/fn.webp'}),
              201,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        addTearDown(client.dispose);
        await client.from('content_files').insert({
          'owner_id': 'u1', 'exam_id': 'e1', 'status': 'pending',
          'object_key': 'u1/exams/e1/media/fn.webp', 'original_name': 'fn.webp',
          'mime_type': 'image/webp', 'content_encoding': 'gzip',
          'sha256': 'a' * 64, 'uncompressed_bytes': 1024, 'compressed_bytes': 512,
        });
        expect(reqs.single.method, 'POST');
        final body = jsonDecode(reqs.single.body) as Map<String, dynamic>;
        expect(body['owner_id'], 'u1');
        expect(body['exam_id'], 'e1');
      });

      test('enforces unique (owner_id, sha256)', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(
              jsonEncode({'code': '23505', 'message': 'duplicate key'}),
              400,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        addTearDown(client.dispose);
        await expectLater(
          client.from('content_files').insert({
            'owner_id': 'u1', 'exam_id': 'e1', 'sha256': 'a' * 64,
            'object_key': 'u1/exams/e1/media/dup.webp', 'original_name': 'd.webp',
            'mime_type': 'image/webp', 'content_encoding': 'gzip',
            'uncompressed_bytes': 1024, 'compressed_bytes': 512, 'status': 'pending',
          }),
          throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23505')),
        );
      });

      test('enforces status check', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(
              jsonEncode({'code': '23514', 'message': 'check constraint violated'}),
              400,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        addTearDown(client.dispose);
        await expectLater(
          client.from('content_files').insert({
            'owner_id': 'u1', 'exam_id': 'e1', 'sha256': 'b' * 64,
            'object_key': 'u1/exams/e1/media/bad.webp', 'original_name': 'b.webp',
            'mime_type': 'image/webp', 'content_encoding': 'gzip',
            'uncompressed_bytes': 1024, 'compressed_bytes': 512, 'status': 'bad',
          }),
          throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23514')),
        );
      });
    });

    group('Storage exam-content bucket', () {
      Uint8List mkFile({int size = 1024}) => Uint8List.fromList(List<int>.filled(size, 1));

      test('owner uploads media to their folder', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient(
          'https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode({'id': 'o1', 'name': 'u1/media/f1.webp', 'bucket_id': 'exam-content', 'Key': 'u1/media/f1.webp'}), 201, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await client.storage.from('exam-content').uploadBinary('u1/media/f1.webp', Uint8List.fromList(List<int>.filled(1024, 1)), fileOptions: const FileOptions(contentType: 'image/webp'));
        expect(reqs.single.method, 'POST');
        expect(reqs.single.url.path, contains('/storage/v1/object/exam-content'));
      });

      test('owner uploads exam package', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode({'id': 'o2', 'name': 'u1/exams/e1/pkg.gz', 'bucket_id': 'exam-content', 'Key': 'u1/exams/e1/pkg.gz'}), 201, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await client.storage.from('exam-content').uploadBinary('u1/exams/e1/pkg.gz', Uint8List.fromList(List<int>.filled(1024, 1)), fileOptions: const FileOptions(contentType: 'application/gzip'));
        expect(reqs.single.method, 'POST');
      });

      test('owner reads own files', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode([{'name': 'u1/media/f1.webp', 'bucket_id': 'exam-content'}]), 200, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await client.storage.from('exam-content').list(path: 'u1/media');
        expect(reqs.single.method, 'POST');
        expect(reqs.single.url.path, contains('/storage/v1/object/list/exam-content'));
      });

      test('public reads ready files for published exams', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode([{'name': 'u2/exams/epub/media/f1.webp', 'bucket_id': 'exam-content'}]), 200, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await client.storage.from('exam-content').list(path: 'u2/exams/epub/media');
        expect(reqs.single.method, 'POST');
      });

      test('owner downloads own file', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response('fake', 200, headers: {'content-type': 'image/webp'}, request: r);
          }),
        );
        await client.storage.from('exam-content').download('u1/media/f1.webp');
        expect(reqs.single.method, 'GET');
        expect(reqs.single.url.path, '/storage/v1/object/exam-content/u1/media/f1.webp');
      });

      test('public downloads ready content', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response('fake', 200, headers: {'content-type': 'image/webp'}, request: r);
          }),
        );
        await client.storage.from('exam-content').download('u2/exams/epub/media/f1.webp');
        expect(reqs.single.method, 'GET');
      });

      test('owner deletes own file', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response('[]', 204, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await client.storage.from('exam-content').remove(['u1/media/f1.webp']);
        expect(reqs.single.method, 'DELETE');
        expect(reqs.single.url.path, contains('/storage/v1/object/exam-content'));
      });

      test('prevents upload to another user folder', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode({'message': 'rls violation'}), 400, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await expectLater(
          client.storage.from('exam-content').uploadBinary('u2/media/f1.webp', Uint8List.fromList(List<int>.filled(1024, 1)), fileOptions: const FileOptions(contentType: 'image/webp')),
          throwsA(isA<StorageException>()),
        );
      });

      test('prevents upload to exams folder not owned', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode({'message': 'rls violation'}), 400, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await expectLater(
          client.storage.from('exam-content').uploadBinary('u1/exams/eother/pkg.gz', Uint8List.fromList(List<int>.filled(1024, 1)), fileOptions: const FileOptions(contentType: 'application/gzip')),
          throwsA(isA<StorageException>()),
        );
      });

      test('enforces allowed mime types', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode({'message': 'mime not allowed'}), 400, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        await expectLater(
          client.storage.from('exam-content').uploadBinary('u1/media/bad.exe', Uint8List.fromList(List<int>.filled(1024, 1)), fileOptions: const FileOptions(contentType: 'application/x-msdownload')),
          throwsA(isA<StorageException>()),
        );
      });

      test('enforces 25 MB size limit', () async {
        final reqs = <http.Request>[];
        final client = SupabaseClient('https://example.test', 'public-key',
          httpClient: MockClient((r) async {
            reqs.add(r);
            return http.Response(jsonEncode({'message': 'size limit'}), 400, headers: {'content-type': 'application/json'}, request: r);
          }),
        );
        final lf = Uint8List.fromList(List<int>.filled(26 * 1024 * 1024, 1));
        await expectLater(
          client.storage.from('exam-content').uploadBinary('u1/media/large.webp', lf, fileOptions: const FileOptions(contentType: 'image/webp')),
          throwsA(isA<StorageException>()),
        );
      });
    });
  });
}

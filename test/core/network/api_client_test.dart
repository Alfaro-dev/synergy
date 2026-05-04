import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synergy/core/network/api_client.dart';
import 'package:synergy/core/errors/exceptions.dart';

void main() {
  setUpAll(() async {
    await dotenv.load();
  });

  group('ApiClient', () {
    group('getNonce', () {
      test('returns nonce on successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/auth/nonce');
          return http.Response('{"nonce": "test-nonce-123"}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.getNonce();

        expect(result['nonce'], 'test-nonce-123');
      });

      test('throws rate limit exception on 429', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "rate_limit_exceeded"}', 429);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.getNonce(),
          throwsA(isA<RateLimitException>()),
        );
      });

      test('throws server exception on 500', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "internal"}', 500);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.getNonce(),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('verifySignature', () {
      test('returns token and expires_at on successful verification', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/auth/verify');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body);
          expect(body['message'], 'test-message');
          expect(body['signature'], 'test-signature');
          return http.Response(
            '{"token": "jwt-token", "expires_at": 1746113400, "is_new_user": true}',
            200,
          );
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.verifySignature(
          message: 'test-message',
          signature: 'test-signature',
        );

        expect(result['token'], 'jwt-token');
        expect(result['expires_at'], 1746113400);
        expect(result['is_new_user'], true);
      });

      test('throws invalid nonce on 401 with invalid_nonce error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "invalid_nonce"}', 401);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.verifySignature(message: 'msg', signature: 'sig'),
          throwsA(isA<InvalidNonceException>()),
        );
      });

      test('throws invalid signature on 401 with invalid_signature error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "invalid_signature"}', 401);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.verifySignature(message: 'msg', signature: 'sig'),
          throwsA(isA<InvalidSignatureException>()),
        );
      });

      test('throws unauthorized on 401 without specific error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "some_error"}', 401);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.verifySignature(message: 'msg', signature: 'sig'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('logout', () {
      test('completes successfully on 204', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/auth/logout');
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('', 204);
        });
        final apiClient = ApiClient(client: mockClient);

        await expectLater(
          apiClient.logout('test-token'),
          completes,
        );
      });

      test('completes successfully on 200', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        await expectLater(
          apiClient.logout('test-token'),
          completes,
        );
      });

      test('throws exception on other status codes', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "unauthorized"}', 401);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.logout('test-token'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('getPublicFeed', () {
      test('returns posts on successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/public/feed');
          expect(request.url.queryParameters['limit'], '20');
          return http.Response(
            '{"posts": [], "has_more": false}',
            200,
          );
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.getPublicFeed();

        expect(result['posts'], isEmpty);
        expect(result['has_more'], false);
      });

      test('includes before cursor when provided', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['before'], '2026-05-01T00:00:00Z');
          return http.Response('{"posts": [], "has_more": false}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        await apiClient.getPublicFeed(before: '2026-05-01T00:00:00Z');
      });

      test('respects custom limit', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['limit'], '50');
          return http.Response('{"posts": [], "has_more": false}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        await apiClient.getPublicFeed(limit: 50);
      });
    });

    group('get', () {
      test('returns data on successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/profile');
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('{"pseudonym": "TestUser"}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.get(endpoint: '/profile', token: 'test-token');

        expect(result['pseudonym'], 'TestUser');
      });

      test('returns empty map on empty body', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.get(endpoint: '/test', token: 'test-token');

        expect(result, isEmpty);
      });

      test('throws unauthorized on 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "unauthorized"}', 401);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('throws token revoked on 401 with token_revoked', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "token_revoked"}', 401);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<TokenRevokedException>()),
        );
      });

      test('throws not found on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "not_found"}', 404);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('throws rate limit on 429', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "rate_limit_exceeded"}', 429);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<RateLimitException>()),
        );
      });
    });

    group('post', () {
      test('returns data on successful 201', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'POST');
          return http.Response('{"community_id": "abc123"}', 201);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.post(
          endpoint: '/communities',
          token: 'test-token',
          body: {'name': 'Test Community'},
        );

        expect(result['community_id'], 'abc123');
      });

      test('returns data on successful 200', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"status": "ok"}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.post(
          endpoint: '/test',
          token: 'test-token',
        );

        expect(result['status'], 'ok');
      });

      test('sends body correctly', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['name'], 'Test Community');
          expect(body['bio'], 'Test bio');
          return http.Response('{}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        await apiClient.post(
          endpoint: '/test',
          token: 'test-token',
          body: {'name': 'Test Community', 'bio': 'Test bio'},
        );
      });

      test('works without body', () async {
        final mockClient = MockClient((request) async {
          expect(request.body, isEmpty);
          return http.Response('{}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        await apiClient.post(endpoint: '/test', token: 'test-token');
      });

      test('throws bad request on 400', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "invalid_body"}', 400);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.post(endpoint: '/test', token: 'test-token'),
          throwsA(isA<BadRequestException>()),
        );
      });

      test('throws forbidden on 403 not_community_creator', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "not_community_creator"}', 403);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.post(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ForbiddenException>()),
        );
      });

      test('throws forbidden on 403 no_active_subscription', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "no_active_subscription"}', 403);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.post(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ForbiddenException>()),
        );
      });

      test('throws forbidden on 403 no_access', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "no_access"}', 403);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.post(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ForbiddenException>()),
        );
      });

      test('throws forbidden on 403 free_community', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "free_community"}', 403);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.post(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ForbiddenException>()),
        );
      });

      test('throws duplicate post on 409 duplicate_post', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "duplicate_post"}', 409);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.post(endpoint: '/test', token: 'test-token'),
          throwsA(isA<DuplicatePostException>()),
        );
      });

      test('throws server busy on 503', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "server_busy"}', 503);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.post(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ServerBusyException>()),
        );
      });
    });

    group('patch', () {
      test('returns data on successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'PATCH');
          return http.Response('{"is_public": true}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.patch(
          endpoint: '/communities/123/visibility',
          token: 'test-token',
          body: {'is_public': true},
        );

        expect(result['is_public'], true);
      });

      test('sends body correctly', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['is_public'], false);
          return http.Response('{}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        await apiClient.patch(
          endpoint: '/test',
          token: 'test-token',
          body: {'is_public': false},
        );
      });
    });

    group('put', () {
      test('returns data on successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'PUT');
          return http.Response('{"pseudonym": "NewName"}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.put(
          endpoint: '/profile',
          token: 'test-token',
          body: {'pseudonym': 'NewName'},
        );

        expect(result['pseudonym'], 'NewName');
      });
    });

    group('getBinary', () {
      test('returns bytes on successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response.bytes([1, 2, 3, 4, 5], 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.getBinary(
          endpoint: '/content/posts/abc123',
          token: 'test-token',
        );

        expect(result, [1, 2, 3, 4, 5]);
      });

      test('throws not found on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "not_found"}', 404);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.getBinary(endpoint: '/test', token: 'test-token'),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('throws content removed on 451', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "content_removed"}', 451);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.getBinary(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ContentRemovedException>()),
        );
      });
    });

    group('getBinaryWithHeaders', () {
      test('returns bytes and encrypted flag on 200', () async {
        final mockClient = MockClient((request) async {
          return http.Response.bytes(
            [1, 2, 3, 4, 5],
            200,
            headers: {'x-encrypted': 'true'},
          );
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.getBinaryWithHeaders(
          endpoint: '/test',
          token: 'test-token',
        );

        expect(result['bytes'], [1, 2, 3, 4, 5]);
        expect(result['encrypted'], true);
      });

      test('returns encrypted false when header not present', () async {
        final mockClient = MockClient((request) async {
          return http.Response.bytes([1, 2, 3], 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.getBinaryWithHeaders(
          endpoint: '/test',
          token: 'test-token',
        );

        expect(result['encrypted'], false);
      });
    });

    group('uploadFileWithFields', () {
      late File tempFile;

      setUp(() async {
        tempFile = File('/tmp/api_client_test_${DateTime.now().millisecondsSinceEpoch}.txt');
        await tempFile.writeAsString('test content');
      });

      tearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      test('returns data on successful upload', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'POST');
          return http.Response('{"cid": "QmTest123"}', 201);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.uploadFileWithFields(
          endpoint: '/content/posts',
          token: 'test-token',
          filePath: tempFile.path,
          fieldName: 'file',
        );

        expect(result['cid'], 'QmTest123');
      });

      test('includes fields in request', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{}', 201);
        });
        final apiClient = ApiClient(client: mockClient);

        await apiClient.uploadFileWithFields(
          endpoint: '/test',
          token: 'test-token',
          filePath: tempFile.path,
          fieldName: 'file',
          fields: {'title': 'Test Title', 'body': 'Test Body'},
        );
      });

      test('uses custom method when specified', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'PATCH');
          return http.Response('{}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        await apiClient.uploadFileWithFields(
          endpoint: '/test',
          token: 'test-token',
          filePath: tempFile.path,
          fieldName: 'avatar',
          method: 'PATCH',
        );
      });
    });

    group('uploadFile', () {
      late File tempFile;

      setUp(() async {
        tempFile = File('/tmp/api_client_test_upload_${DateTime.now().millisecondsSinceEpoch}.txt');
        await tempFile.writeAsString('test content');
      });

      tearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      test('delegates to uploadFileWithFields', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'POST');
          return http.Response('{"avatar_cid": "QmAvatar"}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.uploadFile(
          endpoint: '/communities/123/avatar',
          token: 'test-token',
          filePath: tempFile.path,
          fieldName: 'avatar',
        );

        expect(result['avatar_cid'], 'QmAvatar');
      });
    });

    group('patchFile', () {
      late File tempFile;

      setUp(() async {
        tempFile = File('/tmp/api_client_test_patch_${DateTime.now().millisecondsSinceEpoch}.txt');
        await tempFile.writeAsString('test content');
      });

      tearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      test('uses PATCH method', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'PATCH');
          return http.Response('{"avatar_cid": "QmNewAvatar"}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        final result = await apiClient.patchFile(
          endpoint: '/profile/avatar',
          token: 'test-token',
          filePath: tempFile.path,
          fieldName: 'avatar',
        );

        expect(result['avatar_cid'], 'QmNewAvatar');
      });
    });

    group('error mapping', () {
      test('maps 400 to BadRequestException', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "invalid_body"}', 400);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<BadRequestException>()),
        );
      });

      test('maps 500 with ipfs_unavailable to IpfsUnavailableException', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "ipfs_unavailable"}', 500);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<IpfsUnavailableException>()),
        );
      });

      test('maps unknown error to ServerException', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "unknown_error"}', 500);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ServerException>()),
        );
      });

      test('maps unknown status to ServerException', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 418);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(
          () => apiClient.get(endpoint: '/test', token: 'test-token'),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('dispose', () {
      test('can be called without error', () {
        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });
        final apiClient = ApiClient(client: mockClient);

        expect(() => apiClient.dispose(), returnsNormally);
      });
    });
  });
}
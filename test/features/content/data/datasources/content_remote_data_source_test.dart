import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synergy/core/errors/exceptions.dart';
import 'package:synergy/core/network/api_client.dart';
import 'package:synergy/core/network/secure_storage_service.dart';
import 'package:synergy/features/content/data/datasources/content_remote_data_source.dart';
import 'package:synergy/features/content/data/models/feed_model.dart';
import 'package:synergy/features/content/data/models/post_model.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late ContentRemoteDataSourceImpl dataSource;
  late MockApiClient mockApiClient;
  late MockSecureStorageService mockSecureStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockSecureStorage = MockSecureStorageService();
    dataSource = ContentRemoteDataSourceImpl(
      apiClient: mockApiClient,
      secureStorage: mockSecureStorage,
    );
  });

  group('ContentRemoteDataSource', () {
    const testToken = 'test-jwt-token';

    setUp(() {
      when(() => mockSecureStorage.getValidToken())
          .thenAnswer((_) async => testToken);
    });

    group('getDecryptionKey', () {
      test('returns key without version', () async {
        when(() => mockApiClient.get(
              endpoint: '/content/communities/comm123/key',
              token: testToken,
            )).thenAnswer((_) async => {'key': 'abc123hexkey'});

        final result = await dataSource.getDecryptionKey('comm123');

        expect(result, 'abc123hexkey');
        verify(() => mockApiClient.get(
              endpoint: '/content/communities/comm123/key',
              token: testToken,
            )).called(1);
      });

      test('returns key with version', () async {
        when(() => mockApiClient.get(
              endpoint: '/content/communities/comm123/key?version=2',
              token: testToken,
            )).thenAnswer((_) async => {'key': 'key-v2'});

        final result = await dataSource.getDecryptionKey('comm123', version: 2);

        expect(result, 'key-v2');
        verify(() => mockApiClient.get(
              endpoint: '/content/communities/comm123/key?version=2',
              token: testToken,
            )).called(1);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.getDecryptionKey('comm123'),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('throws unauthorized when token is empty', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => '');

        expect(
          () => dataSource.getDecryptionKey('comm123'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('getPosts', () {
      test('returns posts without before cursor', () async {
        when(() => mockApiClient.get(
              endpoint: '/content/communities/comm123/posts',
              token: testToken,
            )).thenAnswer((_) async => {
              'posts': [
                {
                  'cid': 'QmPost1',
                  'community_id': 'comm123',
                  'author_id': 'author1',
                  'created_at': '2026-05-01T10:00:00.000000000Z',
                  'encrypted': true,
                  'key_version': 1,
                }
              ],
              'has_more': false,
            });

        final result = await dataSource.getPosts('comm123');

        expect(result.posts.length, 1);
        expect(result.posts.first.cid, 'QmPost1');
        expect(result.hasMore, false);
      });

      test('returns posts with before cursor', () async {
        when(() => mockApiClient.get(
              endpoint:
                  '/content/communities/comm123/posts?before=2026-05-01T00:00:00Z',
              token: testToken,
            )).thenAnswer((_) async => {
              'posts': [],
              'has_more': false,
            });

        await dataSource.getPosts('comm123', before: '2026-05-01T00:00:00Z');

        verify(() => mockApiClient.get(
              endpoint:
                  '/content/communities/comm123/posts?before=2026-05-01T00:00:00Z',
              token: testToken,
            )).called(1);
      });
    });

    group('downloadPost', () {
      test('returns binary data', () async {
        when(() => mockApiClient.getBinary(
              endpoint: '/content/communities/comm123/posts/QmPost1',
              token: testToken,
            )).thenAnswer((_) async => [1, 2, 3, 4, 5]);

        final result = await dataSource.downloadPost('comm123', 'QmPost1');

        expect(result, [1, 2, 3, 4, 5]);
      });
    });

    group('getFeed', () {
      test('returns feed without before cursor', () async {
        when(() => mockApiClient.get(
              endpoint: '/content/feed',
              token: testToken,
            )).thenAnswer((_) async => {
              'posts': [
                {
                  'cid': 'QmFeed1',
                  'community_id': 'comm123',
                  'community_name': 'Test Community',
                  'author': {'pseudonym': 'TestUser'},
                  'created_at': '2026-05-01T12:00:00.000000000Z',
                  'has_access': true,
                }
              ],
              'has_more': true,
              'next_before': '2026-05-01T11:00:00.000000000Z',
            });

        final result = await dataSource.getFeed();

        expect(result.posts.length, 1);
        expect(result.hasMore, true);
        expect(result.nextBefore, '2026-05-01T11:00:00.000000000Z');
      });

      test('returns feed with before cursor', () async {
        when(() => mockApiClient.get(
              endpoint: '/content/feed?before=2026-05-01T00:00:00Z',
              token: testToken,
            )).thenAnswer((_) async => {
              'posts': [],
              'has_more': false,
            });

        await dataSource.getFeed(before: '2026-05-01T00:00:00Z');

        verify(() => mockApiClient.get(
              endpoint: '/content/feed?before=2026-05-01T00:00:00Z',
              token: testToken,
            )).called(1);
      });
    });

    group('getPublicFeed', () {
      test('returns public feed without params', () async {
        when(() => mockApiClient.getPublicFeed(before: null, limit: 20))
            .thenAnswer((_) async => {
                  'posts': [
                    {
                      'cid': 'QmPublic1',
                      'community_id': 'comm123',
                      'community_name': 'Public Community',
                      'author': {'pseudonym': 'User1'},
                      'created_at': '2026-05-01T12:00:00.000000000Z',
                      'has_access': false,
                    }
                  ],
                  'has_more': false,
                });

        final result = await dataSource.getPublicFeed();

        expect(result.posts.length, 1);
        expect(result.posts.first.cid, 'QmPublic1');
      });

      test('returns public feed with before and limit', () async {
        when(() => mockApiClient.getPublicFeed(
              before: '2026-05-01T00:00:00Z',
              limit: 10,
            )).thenAnswer((_) async => {
              'posts': [],
              'has_more': false,
            });

        await dataSource.getPublicFeed(before: '2026-05-01T00:00:00Z', limit: 10);

        verify(() => mockApiClient.getPublicFeed(
              before: '2026-05-01T00:00:00Z',
              limit: 10,
            )).called(1);
      });
    });

    group('uploadPost', () {
      test('uploads post with file only', () async {
        when(() => mockApiClient.uploadFileWithFields(
              endpoint: '/content/communities/comm123/posts',
              token: testToken,
              filePath: '/tmp/file.jpg',
              fieldName: 'file',
              fields: null,
            )).thenAnswer((_) async => {'cid': 'QmUploaded'});

        final result = await dataSource.uploadPost(
          communityId: 'comm123',
          filePath: '/tmp/file.jpg',
        );

        expect(result, 'QmUploaded');
      });

      test('uploads post with title and body', () async {
        when(() => mockApiClient.uploadFileWithFields(
              endpoint: '/content/communities/comm123/posts',
              token: testToken,
              filePath: '/tmp/file.jpg',
              fieldName: 'file',
              fields: {'title': 'Test Title', 'body': 'Test Body'},
            )).thenAnswer((_) async => {'cid': 'QmUploaded'});

        final result = await dataSource.uploadPost(
          communityId: 'comm123',
          filePath: '/tmp/file.jpg',
          title: 'Test Title',
          body: 'Test Body',
        );

        expect(result, 'QmUploaded');
      });
    });

    group('uploadGlobalPost', () {
      test('uploads global post with file only', () async {
        when(() => mockApiClient.uploadFileWithFields(
              endpoint: '/content/posts',
              token: testToken,
              filePath: '/tmp/file.jpg',
              fieldName: 'file',
              fields: null,
            )).thenAnswer((_) async => {'cid': 'QmGlobal'});

        final result = await dataSource.uploadGlobalPost(
          filePath: '/tmp/file.jpg',
        );

        expect(result, 'QmGlobal');
      });

      test('uploads global post with title and body', () async {
        when(() => mockApiClient.uploadFileWithFields(
              endpoint: '/content/posts',
              token: testToken,
              filePath: '/tmp/file.jpg',
              fieldName: 'file',
              fields: {'title': 'Global Title'},
            )).thenAnswer((_) async => {'cid': 'QmGlobal'});

        final result = await dataSource.uploadGlobalPost(
          filePath: '/tmp/file.jpg',
          title: 'Global Title',
        );

        expect(result, 'QmGlobal');
      });
    });

    group('downloadGlobalPost', () {
      test('returns binary data', () async {
        when(() => mockApiClient.getBinary(
              endpoint: '/content/posts/QmGlobal1',
              token: testToken,
            )).thenAnswer((_) async => [10, 20, 30]);

        final result = await dataSource.downloadGlobalPost('QmGlobal1');

        expect(result, [10, 20, 30]);
      });
    });

    group('reportCommunityPost', () {
      test('reports with severity only', () async {
        when(() => mockApiClient.post(
              endpoint: '/content/communities/comm123/posts/QmPost1/report',
              token: testToken,
              body: {'severity': 'spam'},
            )).thenAnswer((_) async => {});

        await dataSource.reportCommunityPost(
          communityId: 'comm123',
          cid: 'QmPost1',
          severity: 'spam',
        );

        verify(() => mockApiClient.post(
              endpoint: '/content/communities/comm123/posts/QmPost1/report',
              token: testToken,
              body: {'severity': 'spam'},
            )).called(1);
      });

      test('reports with phash and witness_enc', () async {
        when(() => mockApiClient.post(
              endpoint: '/content/communities/comm123/posts/QmPost1/report',
              token: testToken,
              body: {
                'severity': 'illegal',
                'phash': 'hash123',
                'witness_enc': 'encData',
              },
            )).thenAnswer((_) async => {});

        await dataSource.reportCommunityPost(
          communityId: 'comm123',
          cid: 'QmPost1',
          severity: 'illegal',
          phash: 'hash123',
          witnessEnc: 'encData',
        );

        verify(() => mockApiClient.post(
              endpoint: '/content/communities/comm123/posts/QmPost1/report',
              token: testToken,
              body: {
                'severity': 'illegal',
                'phash': 'hash123',
                'witness_enc': 'encData',
              },
            )).called(1);
      });
    });

    group('reportGlobalPost', () {
      test('reports global post', () async {
        when(() => mockApiClient.post(
              endpoint: '/content/posts/QmGlobal1/report',
              token: testToken,
              body: {'severity': 'csam'},
            )).thenAnswer((_) async => {});

        await dataSource.reportGlobalPost(
          cid: 'QmGlobal1',
          severity: 'csam',
        );

        verify(() => mockApiClient.post(
              endpoint: '/content/posts/QmGlobal1/report',
              token: testToken,
              body: {'severity': 'csam'},
            )).called(1);
      });
    });

    group('rotateCommunityKey', () {
      test('returns new version', () async {
        when(() => mockApiClient.post(
              endpoint: '/content/communities/comm123/rotate-key',
              token: testToken,
            )).thenAnswer((_) async => {'new_version': 3});

        final result = await dataSource.rotateCommunityKey('comm123');

        expect(result, 3);
      });
    });
  });
}
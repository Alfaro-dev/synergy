import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synergy/core/errors/exceptions.dart';
import 'package:synergy/core/network/api_client.dart';
import 'package:synergy/core/network/secure_storage_service.dart';
import 'package:synergy/features/community/data/datasources/community_remote_data_source.dart';
import 'package:synergy/features/community/data/models/community_model.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late CommunityRemoteDataSourceImpl dataSource;
  late MockApiClient mockApiClient;
  late MockSecureStorageService mockSecureStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockSecureStorage = MockSecureStorageService();
    dataSource = CommunityRemoteDataSourceImpl(
      apiClient: mockApiClient,
      secureStorage: mockSecureStorage,
    );
  });

  group('CommunityRemoteDataSource', () {
    const testToken = 'test-jwt-token';

    setUp(() {
      when(() => mockSecureStorage.getValidToken())
          .thenAnswer((_) async => testToken);
    });

    group('getCommunities', () {
      test('returns communities without before cursor', () async {
        when(() => mockApiClient.get(
              endpoint: '/communities',
              token: testToken,
            )).thenAnswer((_) async => {
              'communities': [
                {
                  'community_id': 'comm1',
                  'name': 'Community 1',
                  'created_at': '2026-04-01T10:00:00.000000000Z',
                },
                {
                  'community_id': 'comm2',
                  'name': 'Community 2',
                  'created_at': '2026-04-02T10:00:00.000000000Z',
                },
              ],
              'has_more': true,
              'next_before': '2026-04-02T10:00:00.000000000Z',
            });

        final result = await dataSource.getCommunities();

        expect(result.communities.length, 2);
        expect(result.communities.first.id, 'comm1');
        expect(result.hasMore, true);
        expect(result.nextBefore, '2026-04-02T10:00:00.000000000Z');
      });

      test('returns communities with before cursor', () async {
        when(() => mockApiClient.get(
              endpoint: '/communities?before=2026-04-01T00:00:00Z',
              token: testToken,
            )).thenAnswer((_) async => {
              'communities': [],
              'has_more': false,
            });

        await dataSource.getCommunities(before: '2026-04-01T00:00:00Z');

        verify(() => mockApiClient.get(
              endpoint: '/communities?before=2026-04-01T00:00:00Z',
              token: testToken,
            )).called(1);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.getCommunities(),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('createCommunity', () {
      test('creates community with name only', () async {
        when(() => mockApiClient.post(
              endpoint: '/communities',
              token: testToken,
              body: {'name': 'New Community'},
            )).thenAnswer((_) async => {
              'community_id': 'new-comm-id',
              'metadata_cid': 'QmMeta123',
            });

        final result = await dataSource.createCommunity(name: 'New Community');

        expect(result.communityId, 'new-comm-id');
        expect(result.metadataCid, 'QmMeta123');
      });

      test('creates community with name and bio', () async {
        when(() => mockApiClient.post(
              endpoint: '/communities',
              token: testToken,
              body: {'name': 'New Community', 'bio': 'Community description'},
            )).thenAnswer((_) async => {
              'community_id': 'new-comm-id',
              'metadata_cid': 'QmMeta456',
            });

        final result = await dataSource.createCommunity(
          name: 'New Community',
          bio: 'Community description',
        );

        expect(result.communityId, 'new-comm-id');
        verify(() => mockApiClient.post(
              endpoint: '/communities',
              token: testToken,
              body: {'name': 'New Community', 'bio': 'Community description'},
            )).called(1);
      });
    });

    group('getCreatorProfile', () {
      test('returns creator profile', () async {
        when(() => mockApiClient.get(
              endpoint: '/communities/comm123/creator-profile',
              token: testToken,
            )).thenAnswer((_) async => {
              'pseudonym': 'CreatorName',
              'bio': 'Creator bio',
              'avatar_cid': 'QmAvatar123',
            });

        final result = await dataSource.getCreatorProfile('comm123');

        expect(result.pseudonym, 'CreatorName');
        expect(result.bio, 'Creator bio');
        expect(result.avatarCid, 'QmAvatar123');
      });
    });

    group('getCommunityMetadata', () {
      test('returns community metadata', () async {
        when(() => mockApiClient.get(
              endpoint: '/communities/comm123/metadata',
              token: testToken,
            )).thenAnswer((_) async => {
              'name': 'Test Community',
              'bio': 'Test bio',
              'avatar_cid': 'QmAvatar456',
            });

        final result = await dataSource.getCommunityMetadata('comm123');

        expect(result.name, 'Test Community');
        expect(result.bio, 'Test bio');
        expect(result.avatarCid, 'QmAvatar456');
      });
    });

    group('updateCommunityMetadata', () {
      test('updates metadata with name only', () async {
        when(() => mockApiClient.patch(
              endpoint: '/communities/comm123/metadata',
              token: testToken,
              body: {'name': 'Updated Name'},
            )).thenAnswer((_) async => {
              'metadata_cid': 'QmUpdatedMeta',
            });

        final result = await dataSource.updateCommunityMetadata(
          communityId: 'comm123',
          name: 'Updated Name',
        );

        expect(result, 'QmUpdatedMeta');
      });

      test('updates metadata with name, bio, and avatarCid', () async {
        when(() => mockApiClient.patch(
              endpoint: '/communities/comm123/metadata',
              token: testToken,
              body: {
                'name': 'Updated Name',
                'bio': 'Updated bio',
                'avatar_cid': 'QmNewAvatar',
              },
            )).thenAnswer((_) async => {
              'metadata_cid': 'QmUpdatedMeta2',
            });

        final result = await dataSource.updateCommunityMetadata(
          communityId: 'comm123',
          name: 'Updated Name',
          bio: 'Updated bio',
          avatarCid: 'QmNewAvatar',
        );

        expect(result, 'QmUpdatedMeta2');
        verify(() => mockApiClient.patch(
              endpoint: '/communities/comm123/metadata',
              token: testToken,
              body: {
                'name': 'Updated Name',
                'bio': 'Updated bio',
                'avatar_cid': 'QmNewAvatar',
              },
            )).called(1);
      });
    });

    group('updateVisibility', () {
      test('sets community to public', () async {
        when(() => mockApiClient.patch(
              endpoint: '/communities/comm123/visibility',
              token: testToken,
              body: {'is_public': true},
            )).thenAnswer((_) async => {'is_public': true});

        final result = await dataSource.updateVisibility(
          communityId: 'comm123',
          isPublic: true,
        );

        expect(result, true);
      });

      test('sets community to private', () async {
        when(() => mockApiClient.patch(
              endpoint: '/communities/comm123/visibility',
              token: testToken,
              body: {'is_public': false},
            )).thenAnswer((_) async => {'is_public': false});

        final result = await dataSource.updateVisibility(
          communityId: 'comm123',
          isPublic: false,
        );

        expect(result, false);
        verify(() => mockApiClient.patch(
              endpoint: '/communities/comm123/visibility',
              token: testToken,
              body: {'is_public': false},
            )).called(1);
      });
    });

    group('uploadAvatar', () {
      test('uploads avatar and returns CID', () async {
        when(() => mockApiClient.uploadFile(
              endpoint: '/communities/comm123/avatar',
              token: testToken,
              filePath: '/tmp/avatar.jpg',
              fieldName: 'avatar',
            )).thenAnswer((_) async => {'avatar_cid': 'QmAvatarUpload'});

        final result = await dataSource.uploadAvatar(
          communityId: 'comm123',
          filePath: '/tmp/avatar.jpg',
        );

        expect(result, 'QmAvatarUpload');
      });
    });

    group('joinCommunity', () {
      test('joins community successfully', () async {
        when(() => mockApiClient.post(
              endpoint: '/communities/comm123/join',
              token: testToken,
            )).thenAnswer((_) async => {'status': 'joined'});

        await dataSource.joinCommunity('comm123');

        verify(() => mockApiClient.post(
              endpoint: '/communities/comm123/join',
              token: testToken,
            )).called(1);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.joinCommunity('comm123'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('getCategories', () {
      test('returns list of categories', () async {
        when(() => mockApiClient.get(
              endpoint: '/categories',
              token: testToken,
            )).thenAnswer((_) async => {
              'categories': ['Arte', 'Deportes', 'Tecnología'],
            });

        final result = await dataSource.getCategories();

        expect(result, ['Arte', 'Deportes', 'Tecnología']);
        verify(() => mockApiClient.get(
              endpoint: '/categories',
              token: testToken,
            )).called(1);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.getCategories(),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });
  });
}
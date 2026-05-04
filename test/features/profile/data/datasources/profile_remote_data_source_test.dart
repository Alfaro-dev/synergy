import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synergy/core/errors/exceptions.dart';
import 'package:synergy/core/network/api_client.dart';
import 'package:synergy/core/network/secure_storage_service.dart';
import 'package:synergy/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:synergy/features/profile/data/models/profile_model.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late ProfileRemoteDataSourceImpl dataSource;
  late MockApiClient mockApiClient;
  late MockSecureStorageService mockSecureStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockSecureStorage = MockSecureStorageService();
    dataSource = ProfileRemoteDataSourceImpl(
      apiClient: mockApiClient,
      secureStorage: mockSecureStorage,
    );
  });

  group('ProfileRemoteDataSource', () {
    const testToken = 'test-jwt-token';

    setUp(() {
      when(() => mockSecureStorage.getValidToken())
          .thenAnswer((_) async => testToken);
    });

    group('getProfile', () {
      test('returns profile when found', () async {
        when(() => mockApiClient.get(
              endpoint: '/profile',
              token: testToken,
            )).thenAnswer((_) async => {
              'pseudonym': 'TestUser',
              'bio': 'Test bio',
              'avatar_cid': 'QmAvatar123',
            });

        final result = await dataSource.getProfile();

        expect(result, isNotNull);
        expect(result!.pseudonym, 'TestUser');
        expect(result.bio, 'Test bio');
        expect(result.avatarCid, 'QmAvatar123');
      });

      test('returns null when not found', () async {
        when(() => mockApiClient.get(
              endpoint: '/profile',
              token: testToken,
            )).thenThrow(const NotFoundException());

        final result = await dataSource.getProfile();

        expect(result, isNull);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.getProfile(),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('createOrUpdateProfile', () {
      test('creates profile with pseudonym only', () async {
        when(() => mockApiClient.put(
              endpoint: '/profile',
              token: testToken,
              body: {'pseudonym': 'NewUser'},
            )).thenAnswer((_) async => {
              'pseudonym': 'NewUser',
            });

        final result = await dataSource.createOrUpdateProfile(
          pseudonym: 'NewUser',
        );

        expect(result.pseudonym, 'NewUser');
      });

      test('creates profile with pseudonym and bio', () async {
        when(() => mockApiClient.put(
              endpoint: '/profile',
              token: testToken,
              body: {
                'pseudonym': 'NewUser',
                'bio': 'User biography',
              },
            )).thenAnswer((_) async => {
              'pseudonym': 'NewUser',
              'bio': 'User biography',
            });

        final result = await dataSource.createOrUpdateProfile(
          pseudonym: 'NewUser',
          bio: 'User biography',
        );

        expect(result.pseudonym, 'NewUser');
        expect(result.bio, 'User biography');
      });

      test('creates profile with avatar CID', () async {
        when(() => mockApiClient.put(
              endpoint: '/profile',
              token: testToken,
              body: {
                'pseudonym': 'NewUser',
                'avatar_cid': 'QmNewAvatar',
              },
            )).thenAnswer((_) async => {
              'pseudonym': 'NewUser',
              'avatar_cid': 'QmNewAvatar',
            });

        final result = await dataSource.createOrUpdateProfile(
          pseudonym: 'NewUser',
          avatarCid: 'QmNewAvatar',
        );

        expect(result.pseudonym, 'NewUser');
        verify(() => mockApiClient.put(
              endpoint: '/profile',
              token: testToken,
              body: {
                'pseudonym': 'NewUser',
                'avatar_cid': 'QmNewAvatar',
              },
            )).called(1);
      });

      test('creates profile with all fields', () async {
        when(() => mockApiClient.put(
              endpoint: '/profile',
              token: testToken,
              body: {
                'pseudonym': 'FullUser',
                'bio': 'Full bio',
                'avatar_cid': 'QmFullAvatar',
              },
            )).thenAnswer((_) async => {
              'pseudonym': 'FullUser',
              'bio': 'Full bio',
              'avatar_cid': 'QmFullAvatar',
            });

        final result = await dataSource.createOrUpdateProfile(
          pseudonym: 'FullUser',
          bio: 'Full bio',
          avatarCid: 'QmFullAvatar',
        );

        expect(result.pseudonym, 'FullUser');
        expect(result.bio, 'Full bio');
        expect(result.avatarCid, 'QmFullAvatar');
      });
    });

    group('uploadAvatar', () {
      test('uploads avatar and returns CID', () async {
        when(() => mockApiClient.patchFile(
              endpoint: '/profile/avatar',
              token: testToken,
              filePath: '/tmp/avatar.jpg',
              fieldName: 'avatar',
            )).thenAnswer((_) async => {'avatar_cid': 'QmUploadedAvatar'});

        final result = await dataSource.uploadAvatar('/tmp/avatar.jpg');

        expect(result, 'QmUploadedAvatar');
        verify(() => mockApiClient.patchFile(
              endpoint: '/profile/avatar',
              token: testToken,
              filePath: '/tmp/avatar.jpg',
              fieldName: 'avatar',
            )).called(1);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.uploadAvatar('/tmp/avatar.jpg'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('getMemberships', () {
      test('returns memberships with all roles', () async {
        when(() => mockApiClient.get(
              endpoint: '/profile/membership',
              token: testToken,
            )).thenAnswer((_) async => {
              'memberships': [
                {
                  'community_id': 'comm1',
                  'metadata_cid': 'QmMeta1',
                  'role': 'creator',
                },
                {
                  'community_id': 'comm2',
                  'metadata_cid': 'QmMeta2',
                  'role': 'subscriber',
                  'expires_at': '2026-06-01T00:00:00Z',
                },
                {
                  'community_id': 'comm3',
                  'metadata_cid': 'QmMeta3',
                  'role': 'member',
                  'joined_at': '2026-05-01T12:00:00Z',
                },
              ],
            });

        final result = await dataSource.getMemberships();

        expect(result.length, 3);
        expect(result[0].communityId, 'comm1');
        expect(result[0].role, 'creator');
        expect(result[0].isCreator, true);
        expect(result[1].communityId, 'comm2');
        expect(result[1].role, 'subscriber');
        expect(result[1].isSubscriber, true);
        expect(result[1].expiresAt, DateTime.parse('2026-06-01T00:00:00Z'));
        expect(result[2].communityId, 'comm3');
        expect(result[2].role, 'member');
        expect(result[2].isMember, true);
        expect(result[2].joinedAt, DateTime.parse('2026-05-01T12:00:00Z'));
      });

      test('returns empty list when no memberships', () async {
        when(() => mockApiClient.get(
              endpoint: '/profile/membership',
              token: testToken,
            )).thenAnswer((_) async => {'memberships': []});

        final result = await dataSource.getMemberships();

        expect(result, isEmpty);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.getMemberships(),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synergy/core/network/api_client.dart';
import 'package:synergy/features/auth/data/datasources/auth_remote_data_source.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late AuthRemoteDataSourceImpl dataSource;
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
    dataSource = AuthRemoteDataSourceImpl(apiClient: mockApiClient);
  });

  group('AuthRemoteDataSource', () {
    group('getNonce', () {
      test('returns nonce on success', () async {
        when(() => mockApiClient.getNonce())
            .thenAnswer((_) async => {'nonce': 'random-nonce-123'});

        final result = await dataSource.getNonce();

        expect(result, 'random-nonce-123');
        verify(() => mockApiClient.getNonce()).called(1);
      });
    });

    group('verifySignature', () {
      test('returns AuthResponseModel on success', () async {
        when(() => mockApiClient.verifySignature(
              message: 'test-message',
              signature: 'test-signature',
            )).thenAnswer((_) async => {
              'token': 'jwt-token-abc',
              'expires_at': 1746113400,
              'is_new_user': true,
            });

        final result = await dataSource.verifySignature(
          message: 'test-message',
          signature: 'test-signature',
        );

        expect(result.token, 'jwt-token-abc');
        expect(result.expiresAt, 1746113400);
        expect(result.isNewUser, true);
      });

      test('returns is_new_user false when user exists', () async {
        when(() => mockApiClient.verifySignature(
              message: 'test-message',
              signature: 'test-signature',
            )).thenAnswer((_) async => {
              'token': 'jwt-token-abc',
              'expires_at': 1746113400,
              'is_new_user': false,
            });

        final result = await dataSource.verifySignature(
          message: 'test-message',
          signature: 'test-signature',
        );

        expect(result.isNewUser, false);
      });
    });

    group('logout', () {
      test('delegates to apiClient logout', () async {
        when(() => mockApiClient.logout('test-token'))
            .thenAnswer((_) async => {});

        await expectLater(
          dataSource.logout('test-token'),
          completes,
        );

        verify(() => mockApiClient.logout('test-token')).called(1);
      });
    });
  });
}
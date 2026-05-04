import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synergy/core/errors/exceptions.dart';
import 'package:synergy/core/network/api_client.dart';
import 'package:synergy/core/network/secure_storage_service.dart';
import 'package:synergy/features/payments/data/datasources/payments_remote_data_source.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late PaymentsRemoteDataSourceImpl dataSource;
  late MockApiClient mockApiClient;
  late MockSecureStorageService mockSecureStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockSecureStorage = MockSecureStorageService();
    dataSource = PaymentsRemoteDataSourceImpl(
      apiClient: mockApiClient,
      secureStorage: mockSecureStorage,
    );
  });

  group('PaymentsRemoteDataSource', () {
    const testToken = 'test-jwt-token';

    setUp(() {
      when(() => mockSecureStorage.getValidToken())
          .thenAnswer((_) async => testToken);
    });

    group('getVendingAddress', () {
      test('returns vending address on success', () async {
        when(() => mockApiClient.get(
              endpoint: '/payments/vending-address',
              token: testToken,
            )).thenAnswer((_) async => {
              'address': '0x742d35Cc6634C0532925a3b844Bc454e4438f44e',
            });

        final result = await dataSource.getVendingAddress();

        expect(result.address, '0x742d35Cc6634C0532925a3b844Bc454e4438f44e');
        verify(() => mockApiClient.get(
              endpoint: '/payments/vending-address',
              token: testToken,
            )).called(1);
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.getVendingAddress(),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('throws unauthorized when token is empty', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => '');

        expect(
          () => dataSource.getVendingAddress(),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('getBalance', () {
      test('returns balance for community', () async {
        when(() => mockApiClient.get(
              endpoint: '/payments/communities/comm123/balance',
              token: testToken,
            )).thenAnswer((_) async => {
              'community_id': 'comm123',
              'balance_wei': '1500000000000000000',
            });

        final result = await dataSource.getBalance('comm123');

        expect(result.communityId, 'comm123');
        expect(result.balanceWei, '1500000000000000000');
      });

      test('returns zero balance', () async {
        when(() => mockApiClient.get(
              endpoint: '/payments/communities/comm123/balance',
              token: testToken,
            )).thenAnswer((_) async => {
              'community_id': 'comm123',
              'balance_wei': '0',
            });

        final result = await dataSource.getBalance('comm123');

        expect(result.balanceWei, '0');
      });

      test('returns large balance correctly', () async {
        when(() => mockApiClient.get(
              endpoint: '/payments/communities/comm123/balance',
              token: testToken,
            )).thenAnswer((_) async => {
              'community_id': 'comm123',
              'balance_wei': '1000000000000000000000',
            });

        final result = await dataSource.getBalance('comm123');

        expect(result.balanceWei, '1000000000000000000000');
      });

      test('throws unauthorized when token is null', () async {
        when(() => mockSecureStorage.getValidToken())
            .thenAnswer((_) async => null);

        expect(
          () => dataSource.getBalance('comm123'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });
  });
}
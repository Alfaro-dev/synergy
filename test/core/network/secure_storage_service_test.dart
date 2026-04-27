import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:synergy/core/network/secure_storage_service.dart';
import 'package:synergy/features/auth/domain/entities/auth_session.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService', () {
    late MockFlutterSecureStorage mockStorage;
    late SecureStorageService service;

    setUpAll(() {
      registerFallbackValue(const AndroidOptions());
      registerFallbackValue(const IOSOptions());
    });

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      service = SecureStorageService.withStorage(mockStorage);

      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      when(() => mockStorage.deleteAll()).thenAnswer((_) async {});
      when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    });

    group('saveSession', () {
      test('writes token, expiresAt, isNewUser and walletAddress correctly', () async {
        final session = AuthSession(
          token: 'test_token_123',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(1777253250000),
          isNewUser: false,
          walletAddress: '0x1234567890abcdef',
        );

        await service.saveSession(session);

        verifyInOrder([
          () => mockStorage.write(key: 'jwt', value: 'test_token_123'),
          () => mockStorage.write(key: 'jwt_expires_at', value: '1777253250000'),
          () => mockStorage.write(key: 'is_new_user', value: 'false'),
          () => mockStorage.write(key: 'wallet_address', value: '0x1234567890abcdef'),
        ]);
      });

      test('does not write walletAddress when null', () async {
        final session = AuthSession(
          token: 'test_token',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(1777253250000),
          isNewUser: true,
          walletAddress: null,
        );

        await service.saveSession(session);

        verifyNever(() => mockStorage.write(key: 'wallet_address', value: any(named: 'value')));
      });
    });

    group('getValidToken', () {
      test('returns token when valid (not expired)', () async {
        final futureNow = DateTime.now().millisecondsSinceEpoch + 3600000;
        when(() => mockStorage.read(key: 'jwt')).thenAnswer((_) async => 'valid_token');
        when(() => mockStorage.read(key: 'jwt_expires_at')).thenAnswer((_) async => futureNow.toString());
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');
        when(() => mockStorage.read(key: 'wallet_address')).thenAnswer((_) async => '0xabc');

        final result = await service.getValidToken();

        expect(result, 'valid_token');
      });

      test('returns null when token is null', () async {
        when(() => mockStorage.read(key: 'jwt')).thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'jwt_expires_at')).thenAnswer((_) async => '1777253250000');
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');
        when(() => mockStorage.read(key: 'wallet_address')).thenAnswer((_) async => null);

        final result = await service.getValidToken();

        expect(result, null);
      });

      test('returns null when expiresAt is null', () async {
        when(() => mockStorage.read(key: 'jwt')).thenAnswer((_) async => 'some_token');
        when(() => mockStorage.read(key: 'jwt_expires_at')).thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');
        when(() => mockStorage.read(key: 'wallet_address')).thenAnswer((_) async => null);

        final result = await service.getValidToken();

        expect(result, null);
      });

      test('clears session and returns null when token is expired', () async {
        final expiredTime = DateTime.now().millisecondsSinceEpoch - 1000;
        when(() => mockStorage.read(key: 'jwt')).thenAnswer((_) async => 'expired_token');
        when(() => mockStorage.read(key: 'jwt_expires_at')).thenAnswer((_) async => expiredTime.toString());
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');
        when(() => mockStorage.read(key: 'wallet_address')).thenAnswer((_) async => '0xabc');
        when(() => mockStorage.deleteAll()).thenAnswer((_) async {});

        final result = await service.getValidToken();

        expect(result, null);
        verify(() => mockStorage.deleteAll()).called(1);
      });
    });

    group('getSession', () {
      test('returns AuthSession when all data is present and token valid', () async {
        final futureTime = DateTime.now().millisecondsSinceEpoch + 3600000;
        when(() => mockStorage.read(key: 'jwt')).thenAnswer((_) async => 'session_token');
        when(() => mockStorage.read(key: 'jwt_expires_at')).thenAnswer((_) async => futureTime.toString());
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');
        when(() => mockStorage.read(key: 'wallet_address')).thenAnswer((_) async => '0xwallet');

        final result = await service.getSession();

        expect(result, isNotNull);
        expect(result!.token, 'session_token');
        expect(result.isNewUser, false);
        expect(result.walletAddress, '0xwallet');
      });

      test('returns null when token is null', () async {
        when(() => mockStorage.read(key: 'jwt')).thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'jwt_expires_at')).thenAnswer((_) async => '1777253250000');
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');
        when(() => mockStorage.read(key: 'wallet_address')).thenAnswer((_) async => null);

        final result = await service.getSession();

        expect(result, null);
      });

      test('returns null when expiresAt is null', () async {
        when(() => mockStorage.read(key: 'jwt')).thenAnswer((_) async => 'some_token');
        when(() => mockStorage.read(key: 'jwt_expires_at')).thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');
        when(() => mockStorage.read(key: 'wallet_address')).thenAnswer((_) async => null);

        final result = await service.getSession();

        expect(result, null);
      });
    });

    group('clearSession', () {
      test('calls deleteAll on storage', () async {
        when(() => mockStorage.deleteAll()).thenAnswer((_) async {});

        await service.clearSession();

        verify(() => mockStorage.deleteAll()).called(1);
      });
    });

    group('isNewUser', () {
      test('returns true when is_new_user is "true"', () async {
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'true');

        final result = await service.isNewUser();

        expect(result, true);
      });

      test('returns false when is_new_user is "false"', () async {
        when(() => mockStorage.read(key: 'is_new_user')).thenAnswer((_) async => 'false');

        final result = await service.isNewUser();

        expect(result, false);
      });
    });
  });
}
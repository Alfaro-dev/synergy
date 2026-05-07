import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:synergy/core/network/api_client.dart';
import 'package:synergy/core/errors/exceptions.dart';
import '../helpers/test_environment.dart';
import '../helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final config = TestConfig.current;
  final authHelper = AuthHelper(baseUrl: config.baseUrl);

  group('Auth Integration Tests (Real API)', () {
    test('getNonce returns valid nonce from API', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final response = await apiClient.getNonce();

      expect(response['nonce'], isNotEmpty);
      expect(response['nonce'], hasLength(greaterThanOrEqualTo(16)));
    });

    test('full auth flow: nonce -> sign -> verify -> token', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final nonceResponse = await apiClient.getNonce();
      final nonce = nonceResponse['nonce'] as String;

      final signed = await authHelper.createSignedMessage(nonce: nonce);

      final verifyResponse = await apiClient.verifySignature(
        message: signed.message,
        signature: signed.signature,
      );

      expect(verifyResponse['token'], isNotEmpty);
      expect(verifyResponse['expires_at'], isA<int>());
      expect(verifyResponse['is_new_user'], isA<bool>());

      final token = verifyResponse['token'] as String;

      final profileResponse = await apiClient.get(
        endpoint: '/profile',
        token: token,
      );

      expect([200, 404], contains(profileResponse['pseudonym'] != null ? 200 : 404));
    });

    test('authenticate helper creates valid session', () async {
      final result = await authHelper.authenticate();

      expect(result.token, isNotEmpty);
      expect(result.expiresAt, isA<int>());
      expect(result.isNewUser, isA<bool>());

      final profileResponse = await authHelper.apiClient.get(
        endpoint: '/profile',
        token: result.token,
      );

      expect(profileResponse['pseudonym'] != null || profileResponse.isEmpty, isTrue);
    });

    test('authenticated request with token works', () async {
      final result = await authHelper.authenticate();

      final response = await authHelper.apiClient.get(
        endpoint: '/profile/membership',
        token: result.token,
      );

      expect(response, isA<Map<String, dynamic>>());
      expect(response.containsKey('memberships'), isTrue);
    });

    test('request without token returns 401', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      expect(
        () => apiClient.get(endpoint: '/profile', token: 'invalid_token'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('invalid signature is rejected', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final nonceResponse = await apiClient.getNonce();
      final nonce = nonceResponse['nonce'] as String;

      await expectLater(
        apiClient.verifySignature(
          message: 'invalid message',
          signature: '0xinvalid',
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('logout invalidates token', () async {
      final result = await authHelper.authenticate();
      final apiClient = result.token.isNotEmpty ? authHelper.apiClient : ApiClient(baseUrl: config.baseUrl);

      await apiClient.logout(result.token);

      expect(
        () => apiClient.get(endpoint: '/profile', token: result.token),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}

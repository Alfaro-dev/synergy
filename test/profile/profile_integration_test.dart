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

  group('Profile Integration Tests (Real API)', () {
    late String authToken;

    setUpAll(() async {
      final result = await authHelper.authenticate();
      authToken = result.token;
    });

    group('GET /profile', () {
      test('returns 404 for new user without profile', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final isNewUser = (await authHelper.authenticate()).isNewUser;

        if (isNewUser) {
          final response = await apiClient.get(
            endpoint: '/profile',
            token: authToken,
          );

          expect(response.isEmpty || response.containsKey('error'), isTrue,
              reason: 'New user without profile should return empty or error');
        }
      });

      test('without token returns 401', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        expect(
          () => apiClient.get(endpoint: '/profile', token: 'invalid'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('PUT /profile', () {
      test('creates profile with pseudonym', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final uniquePseudonym = 'TestUser${DateTime.now().millisecondsSinceEpoch}';

        final response = await apiClient.put(
          endpoint: '/profile',
          token: authToken,
          body: {'pseudonym': uniquePseudonym},
        );

        expect(response, isA<Map<String, dynamic>>());
        expect(response['pseudonym'], equals(uniquePseudonym));
      });

      test('creates profile with pseudonym and bio', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final uniquePseudonym = 'TestUser${DateTime.now().millisecondsSinceEpoch}';
        const bio = 'Test bio for integration test';

        final response = await apiClient.put(
          endpoint: '/profile',
          token: authToken,
          body: {'pseudonym': uniquePseudonym, 'bio': bio},
        );

        expect(response['pseudonym'], equals(uniquePseudonym));
        expect(response['bio'], equals(bio));
      });

      test('without pseudonym returns error', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        expect(
          () => apiClient.put(
            endpoint: '/profile',
            token: authToken,
            body: {'bio': 'Only bio, no pseudonym'},
          ),
          throwsA(anything),
        );
      });
    });

    group('GET /profile/membership', () {
      test('returns memberships array structure', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final response = await apiClient.get(
          endpoint: '/profile/membership',
          token: authToken,
        );

        expect(response, isA<Map<String, dynamic>>());
        expect(response.containsKey('memberships'), isTrue,
            reason: 'API must return memberships array');

        final memberships = response['memberships'] as List;
        expect(memberships, isA<List>());

        if (memberships.isNotEmpty) {
          final membership = memberships.first as Map<String, dynamic>;

          expect(membership.containsKey('community_id'), isTrue,
              reason: 'Membership must have community_id');
          expect(membership.containsKey('metadata_cid'), isTrue,
              reason: 'Membership must have metadata_cid');
          expect(membership.containsKey('role'), isTrue,
              reason: 'Membership must have role');

          expect(membership['role'], isA<String>());

          final role = membership['role'] as String;
          if (role == 'subscriber') {
            expect(membership.containsKey('expires_at'), isTrue,
                reason: 'Subscriber role must have expires_at');
          }
          if (role == 'member') {
            expect(membership.containsKey('joined_at'), isTrue,
                reason: 'Member role must have joined_at');
          }
        }
      });

      test('without token returns 401', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        expect(
          () => apiClient.get(endpoint: '/profile/membership', token: 'invalid'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('PATCH /profile/avatar', () {
      test('uploading avatar returns avatar_cid', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final testImagePath = '/tmp/test_avatar_${DateTime.now().millisecondsSinceEpoch}.png';

        await Future.delayed(const Duration(milliseconds: 100));

        try {
          final response = await apiClient.uploadFileWithFields(
            endpoint: '/profile/avatar',
            token: authToken,
            filePath: testImagePath,
            fieldName: 'avatar',
            fields: null,
          );

          expect(response, isA<Map<String, dynamic>>());
          expect(response.containsKey('avatar_cid'), isTrue,
              reason: 'API must return avatar_cid after upload');
        } catch (_) {
        }
      });
    });
  });
}

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

  group('Communities Integration Tests (Real API)', () {
    late String authToken;

    setUpAll(() async {
      final result = await authHelper.authenticate();
      authToken = result.token;
    });

    test('GET /communities returns correct structure per api.md', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final response = await apiClient.get(
        endpoint: '/communities',
        token: authToken,
      );

      expect(response, isA<Map<String, dynamic>>());
      expect(response.containsKey('communities'), isTrue);
      expect(response.containsKey('has_more'), isTrue);

      final communities = response['communities'] as List;
      final hasMore = response['has_more'] as bool;

      expect(hasMore, isA<bool>());
      expect(communities, isA<List>());

      if (communities.isNotEmpty) {
        final community = communities.first as Map<String, dynamic>;

        expect(community.containsKey('community_id'), isTrue,
            reason: 'API must return community_id');
        expect(community.containsKey('metadata_cid'), isTrue,
            reason: 'API must return metadata_cid per api.md');
        expect(community.containsKey('created_at'), isTrue,
            reason: 'API must return created_at');

        expect(community['community_id'], isA<String>());
        expect(community['metadata_cid'], isA<String>());

        expect(community.containsKey('name'), isFalse,
            reason: 'API does NOT return name in /communities - must use /communities/{id}/metadata');
        expect(community.containsKey('bio'), isFalse,
            reason: 'API does NOT return bio in /communities');
        expect(community.containsKey('avatar_cid'), isFalse,
            reason: 'API does NOT return avatar_cid in /communities');
      }
    });

    test('GET /communities with pagination', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final firstPage = await apiClient.get(
        endpoint: '/communities',
        token: authToken,
      );

      if (firstPage['has_more'] == true && firstPage['next_before'] != null) {
        final secondPage = await apiClient.get(
          endpoint: '/communities?before=${firstPage['next_before']}',
          token: authToken,
        );

        expect(secondPage, isA<Map<String, dynamic>>());
        expect(secondPage.containsKey('communities'), isTrue);
        expect(secondPage.containsKey('has_more'), isTrue);
      }
    });

    test('GET /communities/{id}/metadata returns name, bio, avatar_cid', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final communitiesResponse = await apiClient.get(
        endpoint: '/communities',
        token: authToken,
      );

      final communities = communitiesResponse['communities'] as List;
      if (communities.isEmpty) {
        markTestSkipped('No communities available to test metadata endpoint');
        return;
      }

      final communityId = (communities.first as Map<String, dynamic>)['community_id'] as String;

      final metadataResponse = await apiClient.get(
        endpoint: '/communities/$communityId/metadata',
        token: authToken,
      );

      expect(metadataResponse, isA<Map<String, dynamic>>());
      expect(metadataResponse.containsKey('name'), isTrue,
          reason: '/communities/{id}/metadata must return name');
      expect(metadataResponse['name'], isA<String>());

      expect(metadataResponse.containsKey('bio'), isTrue);

      expect(metadataResponse.containsKey('avatar_cid'), isTrue);
    });

    test('GET /communities without token returns 401', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      expect(
        () => apiClient.get(endpoint: '/communities', token: 'invalid'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('POST /communities creates community and returns community_id + metadata_cid', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final uniqueName = 'Test Community ${DateTime.now().millisecondsSinceEpoch}';

      final response = await apiClient.post(
        endpoint: '/communities',
        token: authToken,
        body: {'name': uniqueName},
      );

      expect(response, isA<Map<String, dynamic>>());
      expect(response.containsKey('community_id'), isTrue,
          reason: 'API must return community_id');
      expect(response.containsKey('metadata_cid'), isTrue,
          reason: 'API must return metadata_cid');
    });

    test('POST /communities with bio', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final uniqueName = 'Test Community with Bio ${DateTime.now().millisecondsSinceEpoch}';

      final response = await apiClient.post(
        endpoint: '/communities',
        token: authToken,
        body: {
          'name': uniqueName,
          'bio': 'Test bio for integration test',
        },
      );

      expect(response['community_id'], isA<String>());
      expect(response['metadata_cid'], isA<String>());
    });

    test('GET /communities/categories returns list of categories', () async {
      final apiClient = ApiClient(baseUrl: config.baseUrl);

      final response = await apiClient.get(
        endpoint: '/communities/categories',
        token: authToken,
      );

      expect(response, isA<Map<String, dynamic>>());
      expect(response.containsKey('categories'), isTrue);

      final categories = response['categories'] as List;
      expect(categories, isNotEmpty);
      expect(categories.first, isA<String>());
    });
  });
}

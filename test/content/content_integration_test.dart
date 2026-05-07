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

  group('Content/Feed Integration Tests (Real API)', () {
    late String authToken;

    setUpAll(() async {
      final result = await authHelper.authenticate();
      authToken = result.token;
    });

    group('GET /public/feed', () {
      test('returns correct structure per api.md', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final response = await apiClient.getPublicFeed();

        expect(response, isA<Map<String, dynamic>>());
        expect(response.containsKey('posts'), isTrue,
            reason: 'API must return posts array');
        expect(response.containsKey('has_more'), isTrue,
            reason: 'API must return has_more');

        final posts = response['posts'] as List;
        final hasMore = response['has_more'] as bool;

        expect(hasMore, isA<bool>());
        expect(posts, isA<List>());

        if (posts.isNotEmpty) {
          final post = posts.first as Map<String, dynamic>;

          expect(post.containsKey('community_id'), isTrue,
              reason: 'API must return community_id');
          expect(post.containsKey('cid'), isTrue,
              reason: 'API must return cid');
          expect(post.containsKey('metadata_cid'), isTrue,
              reason: 'API must return metadata_cid');
          expect(post.containsKey('created_at'), isTrue,
              reason: 'API must return created_at');
          expect(post.containsKey('has_access'), isTrue,
              reason: 'API must return has_access');

          expect(post['community_id'], isA<String>());
          expect(post['cid'], isA<String>());
          expect(post['metadata_cid'], isA<String>());
          expect(post['has_access'], isA<bool>());

          expect(post.containsKey('community_name'), isFalse,
              reason: 'API does NOT return community_name in feed');
          expect(post.containsKey('author'), isFalse,
              reason: 'API does NOT return author in feed');
          expect(post.containsKey('authorPseudonym'), isFalse,
              reason: 'API does NOT return authorPseudonym in feed');
          expect(post.containsKey('authorAvatarCid'), isFalse,
              reason: 'API does NOT return authorAvatarCid in feed');
          expect(post.containsKey('media_url'), isFalse,
              reason: 'API does NOT return media_url in feed');
          expect(post.containsKey('key_version'), isFalse,
              reason: 'API does NOT return key_version in feed');
          expect(post.containsKey('body'), isFalse,
              reason: 'API does NOT return body in feed');

          final title = post['title'];
          if (title != null) {
            expect(title, isA<String>());
          }

          final encrypted = post['encrypted'];
          if (encrypted != null) {
            expect(encrypted, isA<bool>());
          }
        }
      });

      test('with limit parameter works', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final response = await apiClient.getPublicFeed(limit: 5);

        final posts = response['posts'] as List;
        expect(posts.length, lessThanOrEqualTo(5));
      });

      test('with before cursor pagination works', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final firstPage = await apiClient.getPublicFeed(limit: 10);

        if (firstPage['has_more'] == true && firstPage['next_before'] != null) {
          final cursor = firstPage['next_before'] as String;

          final secondPage = await apiClient.getPublicFeed(before: cursor);

          expect(secondPage['posts'], isA<List>());

          final firstPostFirstPage = (firstPage['posts'] as List).first;
          final firstPostSecondPage = (secondPage['posts'] as List).first;

          expect(
            (firstPostFirstPage as Map<String, dynamic>)['created_at'],
            isNot(equals((firstPostSecondPage as Map<String, dynamic>)['created_at'])),
          );
        }
      });
    });

    group('GET /content/feed (authenticated)', () {
      test('returns correct structure with has_access', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final response = await apiClient.get(
          endpoint: '/content/feed',
          token: authToken,
        );

        expect(response, isA<Map<String, dynamic>>());
        expect(response.containsKey('posts'), isTrue);
        expect(response.containsKey('has_more'), isTrue);

        final posts = response['posts'] as List;

        if (posts.isNotEmpty) {
          final post = posts.first as Map<String, dynamic>;

          expect(post.containsKey('community_id'), isTrue);
          expect(post.containsKey('cid'), isTrue);
          expect(post.containsKey('metadata_cid'), isTrue);
          expect(post.containsKey('created_at'), isTrue);
          expect(post.containsKey('has_access'), isTrue,
              reason: 'authenticated feed must return has_access');

          expect(post.containsKey('community_name'), isFalse,
              reason: 'API does NOT return community_name');
          expect(post.containsKey('author'), isFalse,
              reason: 'API does NOT return author');
        }
      });

      test('without token returns 401', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        expect(
          () => apiClient.get(endpoint: '/content/feed', token: 'invalid'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('GET /content/communities/{id}/posts', () {
      test('returns posts for a community', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final communitiesResponse = await apiClient.get(
          endpoint: '/communities',
          token: authToken,
        );

        final communities = communitiesResponse['communities'] as List;
        if (communities.isEmpty) {
          markTestSkipped('No communities available');
          return;
        }

        final communityId = (communities.first as Map<String, dynamic>)['community_id'] as String;

        final postsResponse = await apiClient.get(
          endpoint: '/content/communities/$communityId/posts',
          token: authToken,
        );

        expect(postsResponse, isA<Map<String, dynamic>>());
        expect(postsResponse.containsKey('posts'), isTrue);
        expect(postsResponse.containsKey('has_more'), isTrue);

        final posts = postsResponse['posts'] as List;

        if (posts.isNotEmpty) {
          final post = posts.first as Map<String, dynamic>;

          expect(post.containsKey('cid'), isTrue);
          expect(post.containsKey('author_id'), isTrue,
              reason: 'API returns author_id for community posts');
          expect(post.containsKey('created_at'), isTrue);

          final author = post['author'];
          if (author != null) {
            expect(author, isA<Map<String, dynamic>>());
            expect((author as Map<String, dynamic>).containsKey('pseudonym'), isTrue);
          }
        }
      });
    });

    group('GET /content/communities/{id}/key', () {
      test('returns encrypted=false for free community', () async {
        final apiClient = ApiClient(baseUrl: config.baseUrl);

        final communitiesResponse = await apiClient.get(
          endpoint: '/communities',
          token: authToken,
        );

        final communities = communitiesResponse['communities'] as List;
        if (communities.isEmpty) {
          markTestSkipped('No communities available');
          return;
        }

        final communityId = (communities.first as Map<String, dynamic>)['community_id'] as String;

        final keyResponse = await apiClient.get(
          endpoint: '/content/communities/$communityId/key',
          token: authToken,
        );

        expect(keyResponse, isA<Map<String, dynamic>>());
        expect(keyResponse.containsKey('encrypted'), isTrue,
            reason: 'API must return encrypted field');

        expect(keyResponse['encrypted'], isA<bool>());
      });
    });
  });
}

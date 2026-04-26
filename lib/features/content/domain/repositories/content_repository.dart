import '../../domain/entities/post.dart';
import '../../domain/entities/feed.dart';

abstract class ContentRepository {
  Future<String> getDecryptionKey(String communityId);
  Future<PostsResponse> getPosts(String communityId, {String? before});
  Future<List<int>> downloadPost(String communityId, String cid);
  Future<FeedResponse> getFeed({String? before});
  Future<String> uploadPost({
    required String communityId,
    required String filePath,
  });
}

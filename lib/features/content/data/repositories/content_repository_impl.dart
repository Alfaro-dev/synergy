import '../../domain/entities/post.dart';
import '../../domain/entities/feed.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/content_remote_data_source.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({required this.remoteDataSource});

  final ContentRemoteDataSource remoteDataSource;

  @override
  Future<String> getDecryptionKey(String communityId) =>
      remoteDataSource.getDecryptionKey(communityId);

  @override
  Future<PostsResponse> getPosts(String communityId, {String? before}) =>
      remoteDataSource.getPosts(communityId, before: before);

  @override
  Future<List<int>> downloadPost(String communityId, String cid) =>
      remoteDataSource.downloadPost(communityId, cid);

  @override
  Future<FeedResponse> getFeed({String? before}) =>
      remoteDataSource.getFeed(before: before);

  @override
  Future<String> uploadPost({
    required String communityId,
    required String filePath,
  }) =>
      remoteDataSource.uploadPost(
        communityId: communityId,
        filePath: filePath,
      );
}

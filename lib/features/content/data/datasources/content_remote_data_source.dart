import 'dart:developer';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage_service.dart';
import '../models/post_model.dart';
import '../models/feed_model.dart';

abstract class ContentRemoteDataSource {
  Future<String> getDecryptionKey(String communityId);
  Future<PostsResponseModel> getPosts(String communityId, {String? before});
  Future<List<int>> downloadPost(String communityId, String cid);
  Future<FeedResponseModel> getFeed({String? before});
  Future<String> uploadPost({
    required String communityId,
    required String filePath,
  });
}

class ContentRemoteDataSourceImpl implements ContentRemoteDataSource {
  ContentRemoteDataSourceImpl({required this.apiClient, required this.secureStorage});

  final ApiClient apiClient;
  final SecureStorageService secureStorage;

  Future<String> _getToken() async {
    final token = await secureStorage.getValidToken() ?? '';
    log('[ContentDataSource] _getToken: ${token.isEmpty ? "EMPTY" : "got ${token.length} chars"}');
    if (token.isEmpty) {
      log('[ContentDataSource] WARNING: token is empty!');
    }
    return token;
  }

  @override
  Future<String> getDecryptionKey(String communityId) async {
    final token = await _getToken();
    final response = await apiClient.get(
      endpoint: '/content/communities/$communityId/key',
      token: token,
    );
    return response['key'] as String;
  }

  @override
  Future<PostsResponseModel> getPosts(String communityId, {String? before}) async {
    final token = await _getToken();
    final endpoint = before != null
        ? '/content/communities/$communityId/posts?before=$before'
        : '/content/communities/$communityId/posts';
    final response = await apiClient.get(endpoint: endpoint, token: token);
    return PostsResponseModel.fromJson(response);
  }

  @override
  Future<List<int>> downloadPost(String communityId, String cid) async {
    final token = await _getToken();
    final response = await apiClient.getBinary(
      endpoint: '/content/communities/$communityId/posts/$cid',
      token: token,
    );
    return response;
  }

  @override
  Future<FeedResponseModel> getFeed({String? before}) async {
    final token = await _getToken();
    log('[ContentDataSource] getFeed called, token length: ${token.length}');
    final endpoint = before != null ? '/content/feed?before=$before' : '/content/feed';
    final response = await apiClient.get(endpoint: endpoint, token: token);
    return FeedResponseModel.fromJson(response);
  }

  @override
  Future<String> uploadPost({
    required String communityId,
    required String filePath,
  }) async {
    final token = await _getToken();
    final response = await apiClient.uploadFile(
      endpoint: '/content/communities/$communityId/posts',
      token: token,
      filePath: filePath,
      fieldName: 'file',
    );
    return response['cid'] as String;
  }
}
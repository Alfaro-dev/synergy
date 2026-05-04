import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage_service.dart';
import '../models/feed_model.dart';
import '../models/post_model.dart';

abstract class ContentRemoteDataSource {
  Future<String> getDecryptionKey(String communityId, {int? version});
  Future<PostsResponseModel> getPosts(String communityId, {String? before});
  Future<List<int>> downloadPost(String communityId, String cid);
  Future<FeedResponseModel> getFeed({String? before});
  Future<FeedResponseModel> getPublicFeed({String? before, int limit = 20});
  Future<String> uploadPost({
    required String communityId,
    required String filePath,
    String? title,
    String? body,
  });
  Future<String> uploadGlobalPost({
    required String filePath,
    String? title,
    String? body,
  });
  Future<List<int>> downloadGlobalPost(String cid);
  Future<void> reportCommunityPost({
    required String communityId,
    required String cid,
    required String severity,
    String? phash,
    String? witnessEnc,
  });
  Future<void> reportGlobalPost({
    required String cid,
    required String severity,
    String? phash,
    String? witnessEnc,
  });
  Future<int> rotateCommunityKey(String communityId);
}

class ContentRemoteDataSourceImpl implements ContentRemoteDataSource {
  ContentRemoteDataSourceImpl({required this.apiClient, required this.secureStorage});

  final ApiClient apiClient;
  final SecureStorageService secureStorage;

  Future<String> _getToken() async {
    final token = await secureStorage.getValidToken();
    if (token == null || token.isEmpty) {
      throw const UnauthorizedException('Sesión no válida o expirada');
    }
    return token;
  }

  @override
  Future<String> getDecryptionKey(String communityId, {int? version}) async {
    final token = await _getToken();
    final endpoint = version != null
        ? '/content/communities/$communityId/key?version=$version'
        : '/content/communities/$communityId/key';
    final response = await apiClient.get(
      endpoint: endpoint,
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
    final endpoint = before != null ? '/content/feed?before=$before' : '/content/feed';
    final response = await apiClient.get(endpoint: endpoint, token: token);
    return FeedResponseModel.fromJson(response);
  }

  @override
  Future<FeedResponseModel> getPublicFeed({String? before, int limit = 20}) async {
    final response = await apiClient.getPublicFeed(before: before, limit: limit);
    return FeedResponseModel.fromJson(response);
  }

  @override
  Future<String> uploadPost({
    required String communityId,
    required String filePath,
    String? title,
    String? body,
  }) async {
    final token = await _getToken();
    final fields = <String, String>{};
    if (title != null) fields['title'] = title;
    if (body != null) fields['body'] = body;

    final response = await apiClient.uploadFileWithFields(
      endpoint: '/content/communities/$communityId/posts',
      token: token,
      filePath: filePath,
      fieldName: 'file',
      fields: fields.isNotEmpty ? fields : null,
    );
    return response['cid'] as String;
  }

  @override
  Future<String> uploadGlobalPost({
    required String filePath,
    String? title,
    String? body,
  }) async {
    final token = await _getToken();
    final fields = <String, String>{};
    if (title != null) fields['title'] = title;
    if (body != null) fields['body'] = body;

    final response = await apiClient.uploadFileWithFields(
      endpoint: '/content/posts',
      token: token,
      filePath: filePath,
      fieldName: 'file',
      fields: fields.isNotEmpty ? fields : null,
    );
    return response['cid'] as String? ?? '';
  }

  @override
  Future<List<int>> downloadGlobalPost(String cid) async {
    final token = await _getToken();
    final response = await apiClient.getBinary(
      endpoint: '/content/posts/$cid',
      token: token,
    );
    return response;
  }

  @override
  Future<void> reportCommunityPost({
    required String communityId,
    required String cid,
    required String severity,
    String? phash,
    String? witnessEnc,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{'severity': severity};
    if (phash != null) body['phash'] = phash;
    if (witnessEnc != null) body['witness_enc'] = witnessEnc;

    await apiClient.post(
      endpoint: '/content/communities/$communityId/posts/$cid/report',
      token: token,
      body: body,
    );
  }

  @override
  Future<void> reportGlobalPost({
    required String cid,
    required String severity,
    String? phash,
    String? witnessEnc,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{'severity': severity};
    if (phash != null) body['phash'] = phash;
    if (witnessEnc != null) body['witness_enc'] = witnessEnc;

    await apiClient.post(
      endpoint: '/content/posts/$cid/report',
      token: token,
      body: body,
    );
  }

  @override
  Future<int> rotateCommunityKey(String communityId) async {
    final token = await _getToken();
    final response = await apiClient.post(
      endpoint: '/content/communities/$communityId/rotate-key',
      token: token,
    );
    return response['new_version'] as int;
  }
}
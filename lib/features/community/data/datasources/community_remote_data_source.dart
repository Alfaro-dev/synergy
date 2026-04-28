import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage_service.dart';
import '../models/community_model.dart';

abstract class CommunityRemoteDataSource {
  Future<CommunitiesResponseModel> getCommunities({String? before});
  Future<CreatorProfileModel> getCreatorProfile(String communityId);
  Future<CommunityMetaModel> getCommunityMetadata(String communityId);
  Future<String> updateCommunityMetadata({
    required String communityId,
    required String name,
    String? bio,
    String? avatarCid,
  });
  Future<bool> updateVisibility({
    required String communityId,
    required bool isPublic,
  });
  Future<String> uploadAvatar({
    required String communityId,
    required String filePath,
  });
}

class CommunityRemoteDataSourceImpl implements CommunityRemoteDataSource {
  CommunityRemoteDataSourceImpl({required this.apiClient, required this.secureStorage});

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
  Future<CommunitiesResponseModel> getCommunities({String? before}) async {
    final token = await _getToken();
    final endpoint = before != null ? '/communities?before=$before' : '/communities';
    final response = await apiClient.get(endpoint: endpoint, token: token);
    return CommunitiesResponseModel.fromJson(response);
  }

  @override
  Future<CreatorProfileModel> getCreatorProfile(String communityId) async {
    final token = await _getToken();
    final response = await apiClient.get(
      endpoint: '/communities/$communityId/creator-profile',
      token: token,
    );
    return CreatorProfileModel.fromJson(response);
  }

  @override
  Future<CommunityMetaModel> getCommunityMetadata(String communityId) async {
    final token = await _getToken();
    final response = await apiClient.get(
      endpoint: '/communities/$communityId/metadata',
      token: token,
    );
    return CommunityMetaModel.fromJson(response);
  }

  @override
  Future<String> updateCommunityMetadata({
    required String communityId,
    required String name,
    String? bio,
    String? avatarCid,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{'name': name};
    if (bio != null) body['bio'] = bio;
    if (avatarCid != null) body['avatar_cid'] = avatarCid;

    final response = await apiClient.post(
      endpoint: '/communities/$communityId/metadata',
      token: token,
      body: body,
    );
    return response['metadata_cid'] as String;
  }

  @override
  Future<bool> updateVisibility({
    required String communityId,
    required bool isPublic,
  }) async {
    final token = await _getToken();
    final response = await apiClient.patch(
      endpoint: '/communities/$communityId/visibility',
      token: token,
      body: {'is_public': isPublic},
    );
    return response['is_public'] as bool;
  }

  @override
  Future<String> uploadAvatar({
    required String communityId,
    required String filePath,
  }) async {
    final token = await _getToken();
    final response = await apiClient.uploadFile(
      endpoint: '/communities/$communityId/avatar',
      token: token,
      filePath: filePath,
      fieldName: 'avatar',
    );
    return response['avatar_cid'] as String;
  }
}

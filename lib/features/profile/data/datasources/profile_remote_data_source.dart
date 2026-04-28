import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage_service.dart';
import '../models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<CreatorProfileModel?> getProfile();
  Future<CreatorProfileModel> createOrUpdateProfile({
    required String pseudonym,
    String? bio,
    String? avatarCid,
  });
  Future<String> uploadAvatar(String filePath);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl({required this.apiClient, required this.secureStorage});

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
  Future<CreatorProfileModel?> getProfile() async {
    try {
      final token = await _getToken();
      final response = await apiClient.get(endpoint: '/profile', token: token);
      return CreatorProfileModel.fromJson(response);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<CreatorProfileModel> createOrUpdateProfile({
    required String pseudonym,
    String? bio,
    String? avatarCid,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{'pseudonym': pseudonym};
    if (bio != null) body['bio'] = bio;
    if (avatarCid != null) body['avatar_cid'] = avatarCid;

    final response = await apiClient.put(
      endpoint: '/profile',
      token: token,
      body: body,
    );
    return CreatorProfileModel.fromJson(response);
  }

  @override
  Future<String> uploadAvatar(String filePath) async {
    final token = await _getToken();
    final response = await apiClient.uploadFile(
      endpoint: '/profile/avatar',
      token: token,
      filePath: filePath,
      fieldName: 'avatar',
    );
    return response['avatar_cid'] as String;
  }
}

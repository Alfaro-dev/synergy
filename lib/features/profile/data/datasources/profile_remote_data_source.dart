import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
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
  ProfileRemoteDataSourceImpl({required this.apiClient, required this.token});

  final ApiClient apiClient;
  final String token;

  @override
  Future<CreatorProfileModel?> getProfile() async {
    try {
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
    final response = await apiClient.uploadFile(
      endpoint: '/profile/avatar',
      token: token,
      filePath: filePath,
      fieldName: 'avatar',
    );
    return response['avatar_cid'] as String;
  }
}

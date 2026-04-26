import '../../domain/entities/creator_profile.dart';

abstract class ProfileRepository {
  Future<CreatorProfile?> getProfile();
  Future<CreatorProfile> createOrUpdateProfile({
    required String pseudonym,
    String? bio,
    String? avatarCid,
  });
  Future<String> uploadAvatar(String filePath);
}

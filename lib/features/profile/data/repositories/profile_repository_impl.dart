import '../../domain/entities/creator_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this.remoteDataSource});

  final ProfileRemoteDataSource remoteDataSource;

  @override
  Future<CreatorProfile?> getProfile() => remoteDataSource.getProfile();

  @override
  Future<CreatorProfile> createOrUpdateProfile({
    required String pseudonym,
    String? bio,
    String? avatarCid,
  }) =>
      remoteDataSource.createOrUpdateProfile(
        pseudonym: pseudonym,
        bio: bio,
        avatarCid: avatarCid,
      );

  @override
  Future<String> uploadAvatar(String filePath) =>
      remoteDataSource.uploadAvatar(filePath);
}

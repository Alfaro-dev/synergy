import '../../domain/entities/community.dart';
import '../../domain/repositories/community_repository.dart';
import '../datasources/community_remote_data_source.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl({required this.remoteDataSource});

  final CommunityRemoteDataSource remoteDataSource;

  @override
  Future<CommunitiesResponse> getCommunities({String? before}) =>
      remoteDataSource.getCommunities(before: before);

  @override
  Future<CreatorProfile> getCreatorProfile(String communityId) =>
      remoteDataSource.getCreatorProfile(communityId);

  @override
  Future<CommunityMeta> getCommunityMetadata(String communityId) =>
      remoteDataSource.getCommunityMetadata(communityId);

  @override
  Future<String> updateCommunityMetadata({
    required String communityId,
    required String name,
    String? bio,
    String? avatarCid,
  }) =>
      remoteDataSource.updateCommunityMetadata(
        communityId: communityId,
        name: name,
        bio: bio,
        avatarCid: avatarCid,
      );

  @override
  Future<bool> updateVisibility({
    required String communityId,
    required bool isPublic,
  }) =>
      remoteDataSource.updateVisibility(
        communityId: communityId,
        isPublic: isPublic,
      );

  @override
  Future<String> uploadAvatar({
    required String communityId,
    required String filePath,
  }) =>
      remoteDataSource.uploadAvatar(
        communityId: communityId,
        filePath: filePath,
      );
}

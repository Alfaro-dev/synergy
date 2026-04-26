import '../../domain/entities/community.dart';

abstract class CommunityRepository {
  Future<CommunitiesResponse> getCommunities({String? before});
  Future<CreatorProfile> getCreatorProfile(String communityId);
  Future<CommunityMeta> getCommunityMetadata(String communityId);
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

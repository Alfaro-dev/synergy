import '../../domain/entities/community.dart';

class CreatorProfileModel extends CreatorProfile {
  const CreatorProfileModel({
    super.avatarCid,
    super.bio,
    required super.pseudonym,
  });

  factory CreatorProfileModel.fromJson(Map<String, dynamic> json) {
    return CreatorProfileModel(
      pseudonym: json['pseudonym'] as String,
      bio: json['bio'] as String?,
      avatarCid: json['avatar_cid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'pseudonym': pseudonym,
        if (bio != null) 'bio': bio,
        if (avatarCid != null) 'avatar_cid': avatarCid,
      };
}

class CommunityMetaModel extends CommunityMeta {
  const CommunityMetaModel({
    super.avatarCid,
    super.bio,
    required super.name,
  });

  factory CommunityMetaModel.fromJson(Map<String, dynamic> json) {
    return CommunityMetaModel(
      name: json['name'] as String,
      bio: json['bio'] as String?,
      avatarCid: json['avatar_cid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (bio != null) 'bio': bio,
        if (avatarCid != null) 'avatar_cid': avatarCid,
      };
}

class CommunityModel extends Community {
  const CommunityModel({
    required super.id,
    required super.name,
    super.avatarCid,
    super.bio,
    required super.isPublic,
    required super.createdAt,
    super.creator,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarCid: json['avatar_cid'] as String?,
      bio: json['bio'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      creator: json['creator'] != null
          ? CreatorProfileModel.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CommunitiesResponseModel extends CommunitiesResponse {
  const CommunitiesResponseModel({
    required super.communities,
    required super.hasMore,
    super.nextBefore,
  });

  factory CommunitiesResponseModel.fromJson(Map<String, dynamic> json) {
    return CommunitiesResponseModel(
      communities: (json['communities'] as List<dynamic>)
          .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool,
      nextBefore: json['next_before'] as String?,
    );
  }
}

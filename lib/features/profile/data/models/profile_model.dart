import '../../domain/entities/creator_profile.dart';

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

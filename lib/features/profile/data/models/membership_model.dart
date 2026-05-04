import '../../domain/entities/membership.dart';

class MembershipModel extends Membership {
  const MembershipModel({
    required super.communityId,
    required super.metadataCid,
    required super.role,
    super.expiresAt,
    super.joinedAt,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      communityId: json['community_id'] as String,
      metadataCid: json['metadata_cid'] as String,
      role: json['role'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
    );
  }
}
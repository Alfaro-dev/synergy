import 'package:equatable/equatable.dart';

class Membership extends Equatable {
  const Membership({
    required this.communityId,
    required this.metadataCid,
    required this.role,
    this.expiresAt,
    this.joinedAt,
  });

  final String communityId;
  final String metadataCid;
  final String role;
  final DateTime? expiresAt;
  final DateTime? joinedAt;

  bool get isCreator => role == 'creator';
  bool get isSubscriber => role == 'subscriber';
  bool get isMember => role == 'member';

  @override
  List<Object?> get props => [communityId, metadataCid, role, expiresAt, joinedAt];
}
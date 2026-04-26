import 'package:equatable/equatable.dart';

class CreatorProfile extends Equatable {
  const CreatorProfile({
    this.avatarCid,
    this.bio,
    required this.pseudonym,
  });

  final String? avatarCid;
  final String? bio;
  final String pseudonym;

  @override
  List<Object?> get props => [avatarCid, bio, pseudonym];
}

class CommunityMeta extends Equatable {
  const CommunityMeta({
    this.avatarCid,
    this.bio,
    required this.name,
  });

  final String? avatarCid;
  final String? bio;
  final String name;

  @override
  List<Object?> get props => [avatarCid, bio, name];
}

class Community extends Equatable {
  const Community({
    required this.id,
    required this.name,
    this.avatarCid,
    this.bio,
    required this.isPublic,
    required this.createdAt,
    this.creator,
  });

  final String id;
  final String name;
  final String? avatarCid;
  final String? bio;
  final bool isPublic;
  final DateTime createdAt;
  final CreatorProfile? creator;

  @override
  List<Object?> get props =>
      [id, name, avatarCid, bio, isPublic, createdAt, creator];
}

class CommunitiesResponse extends Equatable {
  const CommunitiesResponse({
    required this.communities,
    required this.hasMore,
    this.nextBefore,
  });

  final List<Community> communities;
  final bool hasMore;
  final String? nextBefore;

  @override
  List<Object?> get props => [communities, hasMore, nextBefore];
}

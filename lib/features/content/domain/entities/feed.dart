import 'package:equatable/equatable.dart';

class FeedPost extends Equatable {
  const FeedPost({
    required this.cid,
    required this.communityId,
    required this.communityName,
    required this.createdAt,
    this.mediaUrl,
    this.isEncrypted,
    required this.hasAccess,
    this.keyVersion,
    this.title,
    this.body,
    this.authorPseudonym,
    this.authorAvatarCid,
  });

  final String cid;
  final String communityId;
  final String communityName;
  final DateTime createdAt;
  final String? mediaUrl;
  final bool? isEncrypted;
  final bool hasAccess;
  final int? keyVersion;
  final String? title;
  final String? body;
  final String? authorPseudonym;
  final String? authorAvatarCid;

  @override
  List<Object?> get props => [
        cid,
        communityId,
        communityName,
        createdAt,
        mediaUrl,
        isEncrypted,
        hasAccess,
        keyVersion,
        title,
        body,
      ];
}

class FeedResponse extends Equatable {
  const FeedResponse({
    required this.posts,
    required this.hasMore,
    this.nextBefore,
  });

  final List<FeedPost> posts;
  final bool hasMore;
  final String? nextBefore;

  @override
  List<Object?> get props => [posts, hasMore, nextBefore];
}

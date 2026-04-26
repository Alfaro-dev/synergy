import 'package:equatable/equatable.dart';

class FeedPost extends Equatable {
  const FeedPost({
    required this.cid,
    required this.communityId,
    required this.communityName,
    required this.author,
    required this.createdAt,
    this.mediaUrl,
    this.isEncrypted,
    required this.hasAccess,
  });

  final String cid;
  final String communityId;
  final String communityName;
  final String author;
  final DateTime createdAt;
  final String? mediaUrl;
  final bool? isEncrypted;
  final bool hasAccess;

  @override
  List<Object?> get props => [
        cid,
        communityId,
        communityName,
        author,
        createdAt,
        mediaUrl,
        isEncrypted,
        hasAccess,
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

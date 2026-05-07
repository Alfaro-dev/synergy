import 'package:equatable/equatable.dart';

class FeedPost extends Equatable {
  const FeedPost({
    required this.cid,
    required this.communityId,
    required this.metadataCid,
    required this.createdAt,
    this.isEncrypted,
    required this.hasAccess,
    this.title,
  });

  final String cid;
  final String communityId;
  final String metadataCid;
  final DateTime createdAt;
  final bool? isEncrypted;
  final bool hasAccess;
  final String? title;

  @override
  List<Object?> get props => [
        cid,
        communityId,
        metadataCid,
        createdAt,
        isEncrypted,
        hasAccess,
        title,
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
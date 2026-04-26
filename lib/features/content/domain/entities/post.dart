import 'package:equatable/equatable.dart';

class Post extends Equatable {
  const Post({
    required this.cid,
    required this.communityId,
    required this.author,
    required this.createdAt,
    this.mediaUrl,
    this.isEncrypted,
  });

  final String cid;
  final String communityId;
  final String author;
  final DateTime createdAt;
  final String? mediaUrl;
  final bool? isEncrypted;

  @override
  List<Object?> get props =>
      [cid, communityId, author, createdAt, mediaUrl, isEncrypted];
}

class PostsResponse extends Equatable {
  const PostsResponse({
    required this.posts,
    required this.hasMore,
    this.nextBefore,
  });

  final List<Post> posts;
  final bool hasMore;
  final String? nextBefore;

  @override
  List<Object?> get props => [posts, hasMore, nextBefore];
}

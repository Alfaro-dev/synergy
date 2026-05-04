import 'package:equatable/equatable.dart';

class Post extends Equatable {
  const Post({
    required this.cid,
    required this.communityId,
    required this.authorId,
    required this.createdAt,
    this.title,
    this.body,
    this.isEncrypted,
    this.keyVersion,
    this.authorPseudonym,
    this.authorAvatarCid,
  });

  final String cid;
  final String communityId;
  final String authorId;
  final DateTime createdAt;
  final String? title;
  final String? body;
  final bool? isEncrypted;
  final int? keyVersion;
  final String? authorPseudonym;
  final String? authorAvatarCid;

  @override
  List<Object?> get props => [
        cid,
        communityId,
        authorId,
        createdAt,
        title,
        body,
        isEncrypted,
        keyVersion,
      ];
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

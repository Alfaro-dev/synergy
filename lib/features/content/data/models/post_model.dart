import '../../domain/entities/post.dart';

class PostAuthorModel {
  final String pseudonym;
  final String? avatarCid;

  const PostAuthorModel({required this.pseudonym, this.avatarCid});

  factory PostAuthorModel.fromJson(Map<String, dynamic> json) {
    return PostAuthorModel(
      pseudonym: json['pseudonym'] as String,
      avatarCid: json['avatar_cid'] as String?,
    );
  }
}

class PostModel extends Post {
  const PostModel({
    required super.cid,
    required super.communityId,
    required super.authorId,
    required super.createdAt,
    super.title,
    super.body,
    super.isEncrypted,
    super.keyVersion,
    String? authorPseudonym,
    String? authorAvatarCid,
  })  : super(authorPseudonym: authorPseudonym, authorAvatarCid: authorAvatarCid);

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] != null
        ? PostAuthorModel.fromJson(json['author'] as Map<String, dynamic>)
        : null;
    return PostModel(
      cid: json['cid'] as String,
      communityId: json['community_id'] as String,
      authorId: json['author_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['title'] as String?,
      body: json['body'] as String?,
      isEncrypted: json['encrypted'] as bool?,
      keyVersion: json['key_version'] as int?,
      authorPseudonym: author?.pseudonym,
      authorAvatarCid: author?.avatarCid,
    );
  }
}

class PostsResponseModel extends PostsResponse {
  const PostsResponseModel({
    required super.posts,
    required super.hasMore,
    super.nextBefore,
  });

  factory PostsResponseModel.fromJson(Map<String, dynamic> json) {
    return PostsResponseModel(
      posts: (json['posts'] as List<dynamic>)
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool,
      nextBefore: json['next_before'] as String?,
    );
  }
}

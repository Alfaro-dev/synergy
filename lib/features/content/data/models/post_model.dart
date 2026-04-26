import '../../domain/entities/post.dart';

class PostModel extends Post {
  const PostModel({
    required super.cid,
    required super.communityId,
    required super.author,
    required super.createdAt,
    super.mediaUrl,
    super.isEncrypted,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      cid: json['cid'] as String,
      communityId: json['community_id'] as String,
      author: json['author'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrl: json['media_url'] as String?,
      isEncrypted: json['is_encrypted'] as bool?,
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

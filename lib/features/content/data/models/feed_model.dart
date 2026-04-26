import '../../domain/entities/feed.dart';

class FeedPostModel extends FeedPost {
  const FeedPostModel({
    required super.cid,
    required super.communityId,
    required super.communityName,
    required super.author,
    required super.createdAt,
    super.mediaUrl,
    super.isEncrypted,
    required super.hasAccess,
  });

  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    return FeedPostModel(
      cid: json['cid'] as String,
      communityId: json['community_id'] as String,
      communityName: json['community_name'] as String,
      author: json['author'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrl: json['media_url'] as String?,
      isEncrypted: json['is_encrypted'] as bool?,
      hasAccess: json['has_access'] as bool,
    );
  }
}

class FeedResponseModel extends FeedResponse {
  const FeedResponseModel({
    required super.posts,
    required super.hasMore,
    super.nextBefore,
  });

  factory FeedResponseModel.fromJson(Map<String, dynamic> json) {
    return FeedResponseModel(
      posts: (json['posts'] as List<dynamic>)
          .map((e) => FeedPostModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool,
      nextBefore: json['next_before'] as String?,
    );
  }
}

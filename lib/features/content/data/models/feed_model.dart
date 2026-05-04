import '../../domain/entities/feed.dart';

class FeedPostAuthorModel {
  final String pseudonym;
  final String? avatarCid;

  const FeedPostAuthorModel({required this.pseudonym, this.avatarCid});

  factory FeedPostAuthorModel.fromJson(Map<String, dynamic> json) {
    return FeedPostAuthorModel(
      pseudonym: json['pseudonym'] as String,
      avatarCid: json['avatar_cid'] as String?,
    );
  }
}

class FeedPostModel extends FeedPost {
  const FeedPostModel({
    required super.cid,
    required super.communityId,
    required super.communityName,
    required super.createdAt,
    super.mediaUrl,
    super.isEncrypted,
    required super.hasAccess,
    super.keyVersion,
    super.title,
    super.body,
    super.authorPseudonym,
    super.authorAvatarCid,
  });

  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] != null
        ? FeedPostAuthorModel.fromJson(json['author'] as Map<String, dynamic>)
        : null;
    return FeedPostModel(
      cid: json['cid'] as String,
      communityId: json['community_id'] as String,
      communityName: json['community_name'] as String,
      authorPseudonym: author?.pseudonym,
      authorAvatarCid: author?.avatarCid,
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrl: json['media_url'] as String?,
      isEncrypted: json['encrypted'] as bool?,
      hasAccess: json['has_access'] as bool,
      keyVersion: json['key_version'] as int?,
      title: json['title'] as String?,
      body: json['body'] as String?,
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

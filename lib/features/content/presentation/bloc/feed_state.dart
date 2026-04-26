import 'package:equatable/equatable.dart';
import '../../domain/entities/feed.dart';

sealed class FeedState extends Equatable {
  const FeedState();

  @override
  List<Object?> get props => [];
}

final class FeedInitial extends FeedState {
  const FeedInitial();
}

final class FeedLoading extends FeedState {
  const FeedLoading();
}

final class FeedLoaded extends FeedState {
  const FeedLoaded({
    required this.posts,
    required this.hasMore,
    this.nextBefore,
  });

  @override
  List<Object?> get props => [posts, hasMore, nextBefore];

  final List<FeedPost> posts;
  final bool hasMore;
  final String? nextBefore;
}

final class FeedLoadingMore extends FeedState {
  const FeedLoadingMore({
    required this.posts,
    required this.hasMore,
    this.nextBefore,
  });

  @override
  List<Object?> get props => [posts, hasMore, nextBefore];

  final List<FeedPost> posts;
  final bool hasMore;
  final String? nextBefore;
}

final class FeedError extends FeedState {
  const FeedError({required this.message});

  @override
  List<Object?> get props => [message];

  final String message;
}

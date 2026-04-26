import 'package:equatable/equatable.dart';

sealed class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

final class FeedFetchRequested extends FeedEvent {
  const FeedFetchRequested({this.before});
  final String? before;
}

final class FeedRefreshRequested extends FeedEvent {
  const FeedRefreshRequested();
}

final class FeedLoadMoreRequested extends FeedEvent {
  const FeedLoadMoreRequested();
}

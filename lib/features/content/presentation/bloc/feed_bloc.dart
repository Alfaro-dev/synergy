import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/content_repository.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({required this.repository}) : super(const FeedInitial()) {
    on<FeedFetchRequested>(_onFetchRequested);
    on<FeedRefreshRequested>(_onRefreshRequested);
    on<FeedLoadMoreRequested>(_onLoadMoreRequested);
  }

  final ContentRepository repository;

  Future<void> _onFetchRequested(
    FeedFetchRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(const FeedLoading());
    try {
      final response = await repository.getFeed(before: event.before);
      emit(FeedLoaded(
        posts: response.posts,
        hasMore: response.hasMore,
        nextBefore: response.nextBefore,
      ));
    } on AppException catch (e) {
      emit(FeedError(message: e.message));
    }
  }

  Future<void> _onRefreshRequested(
    FeedRefreshRequested event,
    Emitter<FeedState> emit,
  ) async {
    try {
      final response = await repository.getFeed();
      emit(FeedLoaded(
        posts: response.posts,
        hasMore: response.hasMore,
        nextBefore: response.nextBefore,
      ));
    } on AppException catch (e) {
      emit(FeedError(message: e.message));
    }
  }

  Future<void> _onLoadMoreRequested(
    FeedLoadMoreRequested event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FeedLoaded || !currentState.hasMore) return;

    emit(FeedLoadingMore(
      posts: currentState.posts,
      hasMore: currentState.hasMore,
      nextBefore: currentState.nextBefore,
    ));

    try {
      final response = await repository.getFeed(before: currentState.nextBefore);
      emit(FeedLoaded(
        posts: [...currentState.posts, ...response.posts],
        hasMore: response.hasMore,
        nextBefore: response.nextBefore,
      ));
    } on AppException catch (e) {
      emit(FeedError(message: e.message));
    }
  }
}

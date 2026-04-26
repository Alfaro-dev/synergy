import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/community_repository.dart';
import 'community_event.dart';
import 'community_state.dart';

class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  CommunityBloc({required this.repository}) : super(const CommunityInitial()) {
    on<CommunityFetchRequested>(_onFetchRequested);
    on<CommunityRefreshRequested>(_onRefreshRequested);
  }

  final CommunityRepository repository;

  Future<void> _onFetchRequested(
    CommunityFetchRequested event,
    Emitter<CommunityState> emit,
  ) async {
    emit(const CommunityLoading());
    try {
      final response = await repository.getCommunities(before: event.before);
      emit(CommunityLoaded(
        communities: response.communities,
        hasMore: response.hasMore,
        nextBefore: response.nextBefore,
      ));
    } on AppException catch (e) {
      emit(CommunityError(message: e.message));
    }
  }

  Future<void> _onRefreshRequested(
    CommunityRefreshRequested event,
    Emitter<CommunityState> emit,
  ) async {
    try {
      final response = await repository.getCommunities();
      emit(CommunityLoaded(
        communities: response.communities,
        hasMore: response.hasMore,
        nextBefore: response.nextBefore,
      ));
    } on AppException catch (e) {
      emit(CommunityError(message: e.message));
    }
  }
}

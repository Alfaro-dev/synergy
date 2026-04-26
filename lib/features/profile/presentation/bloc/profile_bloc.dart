import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required this.repository}) : super(const ProfileInitial()) {
    on<ProfileFetchRequested>(_onFetchRequested);
    on<ProfileUpdateRequested>(_onUpdateRequested);
  }

  final ProfileRepository repository;

  Future<void> _onFetchRequested(
    ProfileFetchRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final profile = await repository.getProfile();
      if (profile != null) {
        emit(ProfileLoaded(profile: profile));
      } else {
        emit(const ProfileNotFound());
      }
    } on AppException catch (e) {
      emit(ProfileError(message: e.message));
    }
  }

  Future<void> _onUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(ProfileUpdating(profile: currentState.profile));
    } else {
      emit(const ProfileLoading());
    }

    try {
      final profile = await repository.createOrUpdateProfile(
        pseudonym: event.pseudonym,
        bio: event.bio,
      );
      emit(ProfileLoaded(profile: profile));
    } on AppException catch (e) {
      emit(ProfileError(message: e.message));
    }
  }
}

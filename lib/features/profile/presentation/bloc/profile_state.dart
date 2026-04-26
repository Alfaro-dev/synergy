import 'package:equatable/equatable.dart';
import '../../domain/entities/creator_profile.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileNotFound extends ProfileState {
  const ProfileNotFound();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.profile});

  @override
  List<Object?> get props => [profile];

  final CreatorProfile profile;
}

final class ProfileUpdating extends ProfileState {
  const ProfileUpdating({required this.profile});
  final CreatorProfile profile;
}

final class ProfileError extends ProfileState {
  const ProfileError({required this.message});

  @override
  List<Object?> get props => [message];

  final String message;
}

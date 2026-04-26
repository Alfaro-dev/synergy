import 'package:equatable/equatable.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileFetchRequested extends ProfileEvent {
  const ProfileFetchRequested();
}

final class ProfileUpdateRequested extends ProfileEvent {
  const ProfileUpdateRequested({
    required this.pseudonym,
    this.bio,
  });
  final String pseudonym;
  final String? bio;
}

final class ProfileAvatarUploadRequested extends ProfileEvent {
  const ProfileAvatarUploadRequested({required this.filePath});
  final String filePath;
}

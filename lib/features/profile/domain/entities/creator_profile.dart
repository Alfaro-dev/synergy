import 'package:equatable/equatable.dart';

class CreatorProfile extends Equatable {
  const CreatorProfile({
    this.avatarCid,
    this.bio,
    required this.pseudonym,
  });

  final String? avatarCid;
  final String? bio;
  final String pseudonym;

  @override
  List<Object?> get props => [avatarCid, bio, pseudonym];
}

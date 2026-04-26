import 'package:equatable/equatable.dart';
import '../../domain/entities/auth_session.dart';

class AuthSessionModel extends Equatable {
  const AuthSessionModel({
    required this.token,
    required this.expiresAt,
    required this.isNewUser,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) =>
      AuthSessionModel(
        token: json['token'] as String,
        expiresAt: (json['expires_at'] as num).toInt(),
        isNewUser: json['is_new_user'] as bool,
      );

  final String token;
  final int expiresAt;
  final bool isNewUser;

  Map<String, dynamic> toJson() =>
      {'token': token, 'expires_at': expiresAt, 'is_new_user': isNewUser};

  AuthSession toEntity() => AuthSession(
        token: token,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
        isNewUser: isNewUser,
      );

  @override
  List<Object?> get props => [token, expiresAt, isNewUser];
}

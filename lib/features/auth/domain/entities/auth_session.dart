import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.isNewUser,
    this.walletAddress,
  });

  final String token;
  final DateTime expiresAt;
  final bool isNewUser;
  final String? walletAddress;

  @override
  List<Object?> get props => [token, expiresAt, isNewUser, walletAddress];
}

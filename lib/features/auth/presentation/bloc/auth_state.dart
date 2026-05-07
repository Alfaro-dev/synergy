import 'package:equatable/equatable.dart';
import '../../domain/entities/auth_session.dart';

enum AuthErrorType {
  signatureRejected,
  nonceExpired,
  noConnection,
  noWalletInstalled,
  wrongNetwork,
  serverError,
}

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoadingNonce extends AuthState {
  const AuthLoadingNonce();
}

final class AuthWaitingSignature extends AuthState {
  const AuthWaitingSignature({required this.nonce, this.address = ''});

  @override
  List<Object?> get props => [nonce, address];

  final String nonce;
  final String address;
}

final class AuthValidating extends AuthState {
  const AuthValidating();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.session});

  @override
  List<Object?> get props => [session];

  final AuthSession session;
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.fromExplicitLogout = false});

  @override
  List<Object?> get props => [fromExplicitLogout];

  final bool fromExplicitLogout;
}

final class AuthError extends AuthState {
  const AuthError({
    required this.type,
    required this.message,
  });

  @override
  List<Object?> get props => [type, message];

  final AuthErrorType type;
  final String message;
}

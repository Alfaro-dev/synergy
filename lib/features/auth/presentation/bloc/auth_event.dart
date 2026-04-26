import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

final class AuthConnectWallet extends AuthEvent {
  const AuthConnectWallet();
}

final class AuthSignatureReceived extends AuthEvent {
  const AuthSignatureReceived({
    required this.message,
    required this.signature,
  });

  @override
  List<Object?> get props => [message, signature];

  final String message;
  final String signature;
}

final class AuthSignatureRejected extends AuthEvent {
  const AuthSignatureRejected();
}

final class AuthErrorDismissed extends AuthEvent {
  const AuthErrorDismissed();
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthWalletConnected extends AuthEvent {
  const AuthWalletConnected({required this.address});

  @override
  List<Object?> get props => [address];

  final String address;
}

final class AuthWalletDisconnected extends AuthEvent {
  const AuthWalletDisconnected();
}

final class AuthInitiateSign extends AuthEvent {
  const AuthInitiateSign({required this.address});

  @override
  List<Object?> get props => [address];

  final String address;
}

final class AuthSignResult extends AuthEvent {
  const AuthSignResult({required this.message, required this.signature});

  @override
  List<Object?> get props => [message, signature];

  final String message;
  final String signature;
}

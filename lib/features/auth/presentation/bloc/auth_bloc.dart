import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/usecases/check_auth_status.dart';
import '../../domain/usecases/get_nonce.dart';
import '../../domain/usecases/get_saved_session.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/verify_signature.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this.getNonce,
    required this.verifySignature,
    required this.checkAuthStatus,
    required this.logout,
    required this.getSavedSession,
  }) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthConnectWallet>(_onConnectWallet);
    on<AuthSignatureReceived>(_onSignatureReceived);
    on<AuthSignatureRejected>(_onSignatureRejected);
    on<AuthErrorDismissed>(_onErrorDismissed);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthWalletConnected>(_onWalletConnected);
    on<AuthWalletDisconnected>(_onWalletDisconnected);
    on<AuthInitiateSign>(_onInitiateSign);
    on<AuthSignResult>(_onSignResult);
  }

  final GetNonce getNonce;
  final VerifySignature verifySignature;
  final CheckAuthStatus checkAuthStatus;
  final Logout logout;
  final GetSavedSession getSavedSession;

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingNonce());
    try {
      final isLoggedIn = await checkAuthStatus();
      if (isLoggedIn) {
        emit(const AuthUnauthenticated());
      } else {
        emit(const AuthUnauthenticated());
      }
    } on AppException catch (e) {
      emit(AuthError(type: AuthErrorType.serverError, message: e.message));
    }
  }

  Future<void> _onConnectWallet(
    AuthConnectWallet event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingNonce());
    try {
      final nonce = await getNonce();
      emit(AuthWaitingSignature(nonce: nonce));
    } on InvalidNonceException {
      emit(const AuthError(
        type: AuthErrorType.nonceExpired,
        message: 'La sesión expiró. Intentá de nuevo.',
      ));
    } on NetworkException {
      emit(const AuthError(
        type: AuthErrorType.noConnection,
        message: 'Sin conexión. Revisá tu internet e intentá de nuevo.',
      ));
    } on AppException catch (e) {
      emit(AuthError(type: AuthErrorType.serverError, message: e.message));
    }
  }

  Future<void> _onSignatureReceived(
    AuthSignatureReceived event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthValidating());
    try {
      final session = await verifySignature(
        message: event.message,
        signature: event.signature,
      );
      emit(AuthAuthenticated(session: session));
    } on InvalidNonceException {
      emit(const AuthError(
        type: AuthErrorType.nonceExpired,
        message: 'La sesión expiró. Intentá de nuevo.',
      ));
    } on InvalidSignatureException {
      emit(const AuthError(
        type: AuthErrorType.signatureRejected,
        message: 'La firma no es válida. Intentá de nuevo.',
      ));
    } on NetworkException {
      emit(const AuthError(
        type: AuthErrorType.noConnection,
        message: 'Sin conexión. Revisá tu internet e intentá de nuevo.',
      ));
    } on AppException catch (e) {
      emit(AuthError(type: AuthErrorType.serverError, message: e.message));
    }
  }

  void _onSignatureRejected(
    AuthSignatureRejected event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthError(
      type: AuthErrorType.signatureRejected,
      message: 'Cancelaste la firma. Podés intentarlo de nuevo.',
    ));
  }

  void _onErrorDismissed(
    AuthErrorDismissed event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthUnauthenticated());
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onWalletConnected(
    AuthWalletConnected event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingNonce());
    try {
      final nonce = await getNonce();
      emit(AuthWaitingSignature(nonce: nonce, address: event.address));
    } on InvalidNonceException {
      emit(const AuthError(
        type: AuthErrorType.nonceExpired,
        message: 'La sesión expiró. Intentá de nuevo.',
      ));
    } on NetworkException {
      emit(const AuthError(
        type: AuthErrorType.noConnection,
        message: 'Sin conexión. Revisá tu internet e intentá de nuevo.',
      ));
    } on AppException catch (e) {
      emit(AuthError(type: AuthErrorType.serverError, message: e.message));
    }
  }

  void _onWalletDisconnected(
    AuthWalletDisconnected event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthUnauthenticated());
  }

  Future<void> _onInitiateSign(
    AuthInitiateSign event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingNonce());
    try {
      final nonce = await getNonce();
      emit(AuthWaitingSignature(nonce: nonce, address: event.address));
    } on InvalidNonceException {
      emit(const AuthError(
        type: AuthErrorType.nonceExpired,
        message: 'La sesión expiró. Intentá de nuevo.',
      ));
    } on NetworkException {
      emit(const AuthError(
        type: AuthErrorType.noConnection,
        message: 'Sin conexión. Revisá tu internet e intentá de nuevo.',
      ));
    } on AppException catch (e) {
      emit(AuthError(type: AuthErrorType.serverError, message: e.message));
    }
  }

  Future<void> _onSignResult(
    AuthSignResult event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthValidating());
    final session = await getSavedSession();
    if (session != null) {
      emit(AuthAuthenticated(session: session));
    } else {
      emit(const AuthError(
        type: AuthErrorType.serverError,
        message: 'No se encontró la sesión. Intentá de nuevo.',
      ));
    }
  }
}

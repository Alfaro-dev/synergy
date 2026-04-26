import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<String> getNonce();
  Future<AuthSession> verifyAndLogin({
    required String message,
    required String signature,
  });
  Future<bool> isLoggedIn();
  Future<AuthSession?> getSession();
  Future<void> logout();
}

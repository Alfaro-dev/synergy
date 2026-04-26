import '../../../../core/network/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';

abstract class AuthLocalDataSource {
  Future<void> saveSession(AuthSession session);
  Future<bool> isLoggedIn();
  Future<AuthSession?> getSession();
  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({required this.secureStorage});
  final SecureStorageService secureStorage;

  @override
  Future<void> saveSession(AuthSession session) async {
    await secureStorage.saveSession(session);
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await secureStorage.getValidToken();
    return token != null;
  }

  @override
  Future<AuthSession?> getSession() => secureStorage.getSession();

  @override
  Future<void> clearSession() => secureStorage.clearSession();
}

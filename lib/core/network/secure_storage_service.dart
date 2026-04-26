import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/domain/entities/auth_session.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'jwt';
  static const String _expiresAtKey = 'jwt_expires_at';
  static const String _isNewUserKey = 'is_new_user';
  static const String _addressKey = 'wallet_address';

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _expiresAtKey,
      value: session.expiresAt.millisecondsSinceEpoch.toString(),
    );
    await _storage.write(key: _isNewUserKey, value: session.isNewUser.toString());
    if (session.walletAddress != null) {
      await _storage.write(key: _addressKey, value: session.walletAddress);
    }
  }

  Future<String?> getValidToken() async {
    final token = await _storage.read(key: _tokenKey);
    final expiresAtStr = await _storage.read(key: _expiresAtKey);

    if (token == null || expiresAtStr == null) return null;

    final expiresAt = int.parse(expiresAtStr);
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (nowSeconds >= expiresAt) {
      await clearSession();
      return null;
    }

    return token;
  }

  Future<bool> isNewUser() async {
    final value = await _storage.read(key: _isNewUserKey);
    return value == 'true';
  }

Future<AuthSession?> getSession() async {
    final token = await getValidToken();
    if (token == null) return null;

    final expiresAtStr = await _storage.read(key: _expiresAtKey);
    final isNewUserStr = await _storage.read(key: _isNewUserKey);
    final address = await _storage.read(key: _addressKey);

    if (expiresAtStr == null || isNewUserStr == null) return null;

    return AuthSession(
      token: token,
      expiresAt:
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtStr)),
      isNewUser: isNewUserStr == 'true',
      walletAddress: address,
    );
  }

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}

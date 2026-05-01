import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';
import '../../features/auth/domain/entities/auth_session.dart';

class SecureStorageService {
  SecureStorageService._internal({required FlutterSecureStorage storage})
      : _storage = storage;

  static final SecureStorageService _instance = SecureStorageService._internal(
    storage: const FlutterSecureStorage(),
  );

  static SecureStorageService get instance => _instance;

  factory SecureStorageService() => instance;

  @visibleForTesting
  factory SecureStorageService.withStorage(FlutterSecureStorage storage) {
    return SecureStorageService._internal(storage: storage);
  }

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'jwt';
  static const String _expiresAtKey = 'jwt_expires_at';
  static const String _isNewUserKey = 'is_new_user';
  static const String _addressKey = 'wallet_address';

  Future<void> saveSession(AuthSession session) async {
    log('[SecureStorage] saveSession: START (instance hash=${this.hashCode})');
    await _storage.write(key: _tokenKey, value: session.token);
    final expiresAtMs = session.expiresAt.millisecondsSinceEpoch;
    await _storage.write(
      key: _expiresAtKey,
      value: expiresAtMs.toString(),
    );
    await _storage.write(key: _isNewUserKey, value: session.isNewUser.toString());
    if (session.walletAddress != null) {
      await _storage.write(key: _addressKey, value: session.walletAddress);
    }
    log('[SecureStorage] saveSession: END - all values written');
  }

  bool _isInvalidExpiry(String? expiresAtStr) {
    if (expiresAtStr == null) return true;
    if (expiresAtStr.isEmpty) return true;
    if (expiresAtStr == 'null') return true;
    return false;
  }

  Future<String?> getValidToken() async {
    final token = await _storage.read(key: _tokenKey);
    final expiresAtStr = await _storage.read(key: _expiresAtKey);
    final isNewUserStr = await _storage.read(key: _isNewUserKey);
    final address = await _storage.read(key: _addressKey);

    log('[SecureStorage] getValidToken: READ - token=${token != null ? "present" : "null"}, expiresAtStr="$expiresAtStr", isNewUser="$isNewUserStr", address=${address != null ? "present" : "null"}');

    if (token == null || _isInvalidExpiry(expiresAtStr)) {
      log('[SecureStorage] getValidToken: returning null - token or expiresAt invalid');
      return null;
    }

    int expiresAtMs;
    try {
      expiresAtMs = int.parse(expiresAtStr!);
    } catch (_) {
      log('[SecureStorage] getValidToken: invalid expiresAtStr format, clearing session');
      await clearSession();
      return null;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    log('[SecureStorage] getValidToken: PARSED - nowMs=$nowMs, expiresAtMs=$expiresAtMs, diff=${expiresAtMs - nowMs}ms');

    if (nowMs >= expiresAtMs) {
      log('[SecureStorage] getValidToken: token expired, clearing');
      await clearSession();
      return null;
    }

    log('[SecureStorage] getValidToken: returning token (instance hash=${this.hashCode})');
    return token;
  }

  Future<bool> isNewUser() async {
    final value = await _storage.read(key: _isNewUserKey);
    return value == 'true';
  }

Future<AuthSession?> getSession() async {
    log('[SecureStorage] getSession: START (instance hash=${this.hashCode})');
    final token = await getValidToken();
    if (token == null) {
      log('[SecureStorage] getSession: token was null from getValidToken, returning null');
      return null;
    }

    final expiresAtStr = await _storage.read(key: _expiresAtKey);
    final isNewUserStr = await _storage.read(key: _isNewUserKey);
    final address = await _storage.read(key: _addressKey);

    if (expiresAtStr == null || isNewUserStr == null) {
      log('[SecureStorage] getSession: expiresAt or isNewUser is null, returning null');
      return null;
    }

    log('[SecureStorage] getSession: SUCCESS, returning session');
    return AuthSession(
      token: token,
      expiresAt:
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtStr)),
      isNewUser: isNewUserStr == 'true',
      walletAddress: address,
    );
  }

  Future<void> clearSession() async {
    log('[SecureStorage] clearSession: CALLED (instance hash=${this.hashCode})');
    await _storage.deleteAll();
    log('[SecureStorage] clearSession: DONE - all keys deleted');
  }

  Future<void> debugPrintStoredKeys() async {
    final token = await _storage.read(key: _tokenKey);
    final expires = await _storage.read(key: _expiresAtKey);
    final isNewUser = await _storage.read(key: _isNewUserKey);
    final address = await _storage.read(key: _addressKey);
    log('[SecureStorage] Stored keys - jwt: ${token != null ? "present" : "null"}, expires: $expires, isNewUser: $isNewUser, address: $address');
  }
}

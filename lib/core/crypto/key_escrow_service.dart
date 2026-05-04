import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_service.dart';

class KeyEscrowService {
  KeyEscrowService._();

  static final KeyEscrowService instance = KeyEscrowService._();

  final CryptoService _crypto = CryptoService.instance;

  Future<String> createEscrowData({
    required Uint8List privateKey,
    required Uint8List recoveryKey,
  }) async {
    final encryptedPrivateKey = await _crypto.encryptAesGcm(
      plaintext: privateKey,
      key: recoveryKey,
    );

    final escrowData = {
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'encrypted_key': _crypto.bytesToHex(encryptedPrivateKey),
    };

    return base64Encode(utf8.encode(jsonEncode(escrowData)));
  }

  Future<Uint8List?> recoverFromEscrow({
    required String escrowData,
    required Uint8List recoveryKey,
  }) async {
    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(escrowData))) as Map<String, dynamic>;

      if (decoded['version'] != 1) {
        throw const FormatException('Unsupported escrow version');
      }

      final encryptedKeyHex = decoded['encrypted_key'] as String;
      final encryptedKey = _crypto.hexToBytes(encryptedKeyHex);

      return await _crypto.decryptAesGcm(
        ciphertext: encryptedKey,
        key: recoveryKey,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List> deriveRecoveryKeyFromWallet({
    required Uint8List walletPrivateKey,
  }) async {
    return _crypto.deriveKeyFromWallet(
      walletPrivateKey: walletPrivateKey,
      purpose: 'escrow-recovery',
    );
  }

  Future<Uint8List> derivePublishKeyFromWallet({
    required Uint8List walletPrivateKey,
  }) async {
    return _crypto.deriveKeyFromWallet(
      walletPrivateKey: walletPrivateKey,
      purpose: 'publish-key',
    );
  }

  Future<Uint8List> deriveLoginKeyFromWallet({
    required Uint8List walletPrivateKey,
  }) async {
    return _crypto.deriveKeyFromWallet(
      walletPrivateKey: walletPrivateKey,
      purpose: 'login-key',
    );
  }
}
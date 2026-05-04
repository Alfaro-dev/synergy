import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  CryptoService._();

  static final CryptoService instance = CryptoService._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _publishKeyStorageKey = 'synergia_publish_key';
  static const String _escrowStorageKey = 'synergia_escrow_data';

  final _aesGcm = AesGcm.with256bits();

  Future<SecretKey> generateSecretKey() async {
    return await _aesGcm.newSecretKey();
  }

  Future<Uint8List> deriveKeyFromWallet({
    required Uint8List walletPrivateKey,
    required String purpose,
  }) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    final info = 'synergia-$purpose';

    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(walletPrivateKey),
      info: utf8.encode(info),
      nonce: utf8.encode('synergia-salt'),
    );

    return Uint8List.fromList(await derivedKey.extractBytes());
  }

  Future<Uint8List> generateRandomKey() async {
    final secretKey = await _aesGcm.newSecretKey();
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  Future<Uint8List> encryptAesGcm({
    required Uint8List plaintext,
    required Uint8List key,
  }) async {
    final secretKey = SecretKey(key);
    final nonce = _aesGcm.newNonce();

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    return Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
  }

  Future<Uint8List> decryptAesGcm({
    required Uint8List ciphertext,
    required Uint8List key,
  }) async {
    if (ciphertext.length < 28) {
      throw const FormatException('Invalid ciphertext: too short');
    }

    final nonce = ciphertext.sublist(0, 12);
    final cipherText = ciphertext.sublist(12, ciphertext.length - 16);
    final macBytes = ciphertext.sublist(ciphertext.length - 16);

    final secretKey = SecretKey(key);
    final mac = Mac(macBytes);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: mac,
    );

    return Uint8List.fromList(await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    ));
  }

  Future<Uint8List> deriveSharedSecret({
    required Uint8List privateKey,
    required Uint8List publicKey,
  }) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    final sharedSecret = Uint8List.fromList([
      ...privateKey,
      ...publicKey,
    ]);

    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      info: utf8.encode('synergia-shared-secret'),
      nonce: utf8.encode('synergia-salt'),
    );

    return Uint8List.fromList(await derived.extractBytes());
  }

  Future<Uint8List> encryptGroupKey({
    required Uint8List groupKey,
    required Uint8List recipientPublicKey,
  }) async {
    final sharedSecret = await deriveSharedSecret(
      privateKey: groupKey,
      publicKey: recipientPublicKey,
    );

    return await encryptAesGcm(
      plaintext: groupKey,
      key: sharedSecret,
    );
  }

  Future<Uint8List> decryptGroupKey({
    required Uint8List encryptedGroupKey,
    required Uint8List senderPublicKey,
  }) async {
    final sharedSecret = await deriveSharedSecret(
      privateKey: senderPublicKey,
      publicKey: encryptedGroupKey.sublist(0, 32),
    );

    return await decryptAesGcm(
      ciphertext: encryptedGroupKey.sublist(32),
      key: sharedSecret,
    );
  }

  Future<void> storePublishKey(Uint8List publishKey) async {
    await _secureStorage.write(
      key: _publishKeyStorageKey,
      value: bytesToHex(publishKey),
    );
  }

  Future<Uint8List?> getPublishKey() async {
    final stored = await _secureStorage.read(key: _publishKeyStorageKey);
    if (stored == null) return null;
    return hexToBytes(stored);
  }

  Future<bool> hasPublishKey() async {
    return await _secureStorage.read(key: _publishKeyStorageKey) != null;
  }

  Future<void> deletePublishKey() async {
    await _secureStorage.delete(key: _publishKeyStorageKey);
  }

  Future<Uint8List> generateGroupKey() async {
    return generateRandomKey();
  }

  Future<Uint8List> encryptGroupKeyForMember({
    required Uint8List groupKey,
    required Uint8List memberPublicKey,
  }) async {
    return await encryptGroupKey(
      groupKey: groupKey,
      recipientPublicKey: memberPublicKey,
    );
  }

  Future<Uint8List> decryptGroupKeyForSelf({
    required Uint8List encryptedGroupKey,
    required Uint8List myPrivateKey,
  }) async {
    return await decryptAesGcm(
      ciphertext: encryptedGroupKey,
      key: myPrivateKey,
    );
  }

  String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uint8List hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
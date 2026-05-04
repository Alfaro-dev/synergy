import 'dart:io';
import 'dart:typed_data';
import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage_service.dart';

abstract class ContentE2ERemoteDataSource {
  Future<Uint8List> getGroupKey(String communityId);
  Future<void> joinCommunityAndReceiveKey({
    required String communityId,
    required String encryptedKeyRequest,
  });
  Future<String> uploadEncryptedPost({
    required String communityId,
    required Uint8List encryptedContent,
    String? title,
    String? body,
  });
  Future<Uint8List> downloadAndDecryptPost({
    required String communityId,
    required String cid,
    required Uint8List groupKey,
  });
  Future<Uint8List> reEncryptForReport({
    required Uint8List plaintext,
    String? reportPublicKey,
  });
}

class ContentE2ERemoteDataSourceImpl implements ContentE2ERemoteDataSource {
  ContentE2ERemoteDataSourceImpl({
    required this.apiClient,
    required this.secureStorage,
    required this.cryptoService,
  });

  final ApiClient apiClient;
  final SecureStorageService secureStorage;
  final CryptoService cryptoService;

  final Map<String, Uint8List> _groupKeysCache = {};

  Future<String> _getToken() async {
    final token = await secureStorage.getValidToken();
    if (token == null || token.isEmpty) {
      throw const UnauthorizedException('Sesión no válida o expirada');
    }
    return token;
  }

  @override
  Future<Uint8List> getGroupKey(String communityId) async {
    final cached = _groupKeysCache[communityId];
    if (cached != null) {
      return cached;
    }
    throw const NotFoundException('No tienes la clave de esta comunidad');
  }

  @override
  Future<void> joinCommunityAndReceiveKey({
    required String communityId,
    required String encryptedKeyRequest,
  }) async {
    final token = await _getToken();

    final response = await apiClient.post(
      endpoint: '/content/communities/$communityId/join',
      token: token,
      body: {
        'encrypted_key_request': encryptedKeyRequest,
      },
    );

    final encryptedGroupKeyHex = response['encrypted_group_key'] as String;
    final encryptedGroupKey = cryptoService.hexToBytes(encryptedGroupKeyHex);

    final storedKey = await cryptoService.getPublishKey();
    if (storedKey == null) {
      throw const UnauthorizedException('No tienes clave de publicación');
    }

    final groupKey = await cryptoService.decryptGroupKeyForSelf(
      encryptedGroupKey: encryptedGroupKey,
      myPrivateKey: storedKey,
    );

    _groupKeysCache[communityId] = groupKey;
  }

  @override
  Future<String> uploadEncryptedPost({
    required String communityId,
    required Uint8List encryptedContent,
    String? title,
    String? body,
  }) async {
    final token = await _getToken();
    final fields = <String, String>{};
    if (title != null) fields['title'] = title;
    if (body != null) fields['body'] = body;

    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/encrypted_post_${DateTime.now().millisecondsSinceEpoch}.bin');
    await tempFile.writeAsBytes(encryptedContent);

    try {
      final response = await apiClient.uploadFileWithFields(
        endpoint: '/content/communities/$communityId/posts',
        token: token,
        filePath: tempFile.path,
        fieldName: 'file',
        fields: fields.isNotEmpty ? fields : null,
      );
      return response['cid'] as String;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  @override
  Future<Uint8List> downloadAndDecryptPost({
    required String communityId,
    required String cid,
    required Uint8List groupKey,
  }) async {
    final token = await _getToken();
    final ciphertext = await apiClient.getBinary(
      endpoint: '/content/communities/$communityId/posts/$cid',
      token: token,
    );

    return await cryptoService.decryptAesGcm(
      ciphertext: Uint8List.fromList(ciphertext),
      key: groupKey,
    );
  }

  @override
  Future<Uint8List> reEncryptForReport({
    required Uint8List plaintext,
    String? reportPublicKey,
  }) async {
    if (reportPublicKey == null || reportPublicKey.isEmpty) {
      throw const BadRequestException('Se requiere clave pública del admin para reportes');
    }

    final publicKeyBytes = cryptoService.hexToBytes(reportPublicKey);

    final storedKey = await cryptoService.getPublishKey();
    if (storedKey == null) {
      throw const UnauthorizedException('No tienes clave de publicación');
    }

    final encrypted = await cryptoService.encryptGroupKeyForMember(
      groupKey: plaintext,
      memberPublicKey: publicKeyBytes,
    );

    return encrypted;
  }

  void cacheGroupKey(String communityId, Uint8List groupKey) {
    _groupKeysCache[communityId] = groupKey;
  }

  void removeGroupKey(String communityId) {
    _groupKeysCache.remove(communityId);
  }

  void clearCache() {
    _groupKeysCache.clear();
  }
}
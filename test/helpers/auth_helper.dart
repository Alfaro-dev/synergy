import 'package:synergy/core/network/api_client.dart';
import '../fixtures/test_wallet.dart';

class SiweMessage {
  SiweMessage({
    required this.address,
    required this.nonce,
    required this.chainId,
    required this.version,
    required this.uri,
    required this.issuedAt,
    required this.expirationTime,
  });

  final String address;
  final String nonce;
  final int chainId;
  final String version;
  final String uri;
  final DateTime issuedAt;
  final DateTime expirationTime;

  String toMessage() {
    final domain = Uri.parse(uri).host;
    return '''
${domain} wants you to sign in with your Ethereum account:
$address

Sign in to Sinergia

URI: $uri
Version: $version
Chain ID: $chainId
Nonce: $nonce
Issued At: ${issuedAt.toIso8601String()}
Expiration Time: ${expirationTime.toIso8601String()}'''
        .trim();
  }
}

class AuthHelper {
  AuthHelper({required String baseUrl})
      : _baseUrl = baseUrl,
        _apiClient = ApiClient(baseUrl: baseUrl);

  final String _baseUrl;
  final ApiClient _apiClient;

  Future<String> getNonce() async {
    final response = await _apiClient.getNonce();
    return response['nonce'] as String;
  }

  Future<({String message, String signature})> createSignedMessage({
    required String nonce,
    int chainId = 11155111,
    String? uri,
    DateTime? issuedAt,
    DateTime? expirationTime,
  }) async {
    final wallet = TestWallet.instance;
    final now = DateTime.now();

    final siweMessage = SiweMessage(
      address: wallet.addressHex,
      nonce: nonce,
      chainId: chainId,
      version: '1',
      uri: uri ?? _baseUrl,
      issuedAt: issuedAt ?? now,
      expirationTime: expirationTime ?? now.add(const Duration(minutes: 10)),
    );

    final message = siweMessage.toMessage();
    final signature = await wallet.signMessage(message);

    return (message: message, signature: signature);
  }

  Future<({String token, int expiresAt, bool isNewUser})> authenticate() async {
    final nonce = await getNonce();
    final signed = await createSignedMessage(nonce: nonce);
    final response = await _apiClient.verifySignature(
      message: signed.message,
      signature: signed.signature,
    );

    return (
      token: response['token'] as String,
      expiresAt: response['expires_at'] as int,
      isNewUser: response['is_new_user'] as bool,
    );
  }

  ApiClient get apiClient => _apiClient;
}

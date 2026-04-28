import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<String> getNonce();
  Future<AuthSessionModel> verifySignature({
    required String message,
    required String signature,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required this.apiClient});
  final ApiClient apiClient;

  @override
  Future<String> getNonce() async {
    final response = await apiClient.getNonce();
    final nonce = response['nonce'] as String?;
    if (nonce == null) {
      throw const ServerException('Respuesta inválida del servidor: nonce faltante');
    }
    return nonce;
  }

  @override
  Future<AuthSessionModel> verifySignature({
    required String message,
    required String signature,
  }) async {
    final response = await apiClient.verifySignature(
      message: message,
      signature: signature,
    );
    return AuthSessionModel.fromJson(response);
  }
}

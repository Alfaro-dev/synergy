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
    return response['nonce'] as String;
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

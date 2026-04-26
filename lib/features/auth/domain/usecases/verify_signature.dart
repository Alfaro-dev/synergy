import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class VerifySignature {
  const VerifySignature(this._repository);
  final AuthRepository _repository;

  Future<AuthSession> call({
    required String message,
    required String signature,
  }) =>
      _repository.verifyAndLogin(message: message, signature: signature);
}

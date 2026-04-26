import '../repositories/auth_repository.dart';

class GetNonce {
  const GetNonce(this._repository);
  final AuthRepository _repository;

  Future<String> call() => _repository.getNonce();
}

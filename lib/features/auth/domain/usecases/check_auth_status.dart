import '../repositories/auth_repository.dart';

class CheckAuthStatus {
  const CheckAuthStatus(this._repository);
  final AuthRepository _repository;

  Future<bool> call() => _repository.isLoggedIn();
}

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  @override
  Future<String> getNonce() => remoteDataSource.getNonce();

  @override
  Future<AuthSession> verifyAndLogin({
    required String message,
    required String signature,
  }) async {
    final sessionModel = await remoteDataSource.verifySignature(
      message: message,
      signature: signature,
    );
    final session = sessionModel.toEntity();
    await localDataSource.saveSession(session);
    return session;
  }

  @override
  Future<bool> isLoggedIn() => localDataSource.isLoggedIn();

  @override
  Future<AuthSession?> getSession() => localDataSource.getSession();

  @override
  Future<void> logout() => localDataSource.clearSession();
}

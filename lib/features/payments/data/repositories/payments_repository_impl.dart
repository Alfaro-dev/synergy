import '../../domain/entities/payment.dart';
import '../../domain/repositories/payments_repository.dart';
import '../datasources/payments_remote_data_source.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl({required this.remoteDataSource});

  final PaymentsRemoteDataSource remoteDataSource;

  @override
  Future<Balance> getBalance(String communityId) =>
      remoteDataSource.getBalance(communityId);

  @override
  Future<VendingAddress> getVendingAddress() =>
      remoteDataSource.getVendingAddress();
}

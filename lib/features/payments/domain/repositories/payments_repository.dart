import '../../domain/entities/payment.dart';

abstract class PaymentsRepository {
  Future<Balance> getBalance(String communityId);
  Future<VendingAddress> getVendingAddress();
}

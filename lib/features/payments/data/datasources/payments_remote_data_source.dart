import '../../../../core/network/api_client.dart';
import '../models/payment_model.dart';

abstract class PaymentsRemoteDataSource {
  Future<BalanceModel> getBalance(String communityId);
  Future<VendingAddressModel> getVendingAddress();
}

class PaymentsRemoteDataSourceImpl implements PaymentsRemoteDataSource {
  PaymentsRemoteDataSourceImpl({required this.apiClient, required this.token});

  final ApiClient apiClient;
  final String token;

  @override
  Future<BalanceModel> getBalance(String communityId) async {
    final response = await apiClient.get(
      endpoint: '/payments/communities/$communityId/balance',
      token: token,
    );
    return BalanceModel.fromJson(response);
  }

  @override
  Future<VendingAddressModel> getVendingAddress() async {
    final response = await apiClient.get(
      endpoint: '/payments/vending-address',
      token: token,
    );
    return VendingAddressModel.fromJson(response);
  }
}

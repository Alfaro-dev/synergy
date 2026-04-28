import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage_service.dart';
import '../models/payment_model.dart';

abstract class PaymentsRemoteDataSource {
  Future<BalanceModel> getBalance(String communityId);
  Future<VendingAddressModel> getVendingAddress();
}

class PaymentsRemoteDataSourceImpl implements PaymentsRemoteDataSource {
  PaymentsRemoteDataSourceImpl({required this.apiClient, required this.secureStorage});

  final ApiClient apiClient;
  final SecureStorageService secureStorage;

  Future<String> _getToken() async {
    final token = await secureStorage.getValidToken();
    if (token == null || token.isEmpty) {
      throw const UnauthorizedException('Sesión no válida o expirada');
    }
    return token;
  }

  @override
  Future<BalanceModel> getBalance(String communityId) async {
    final token = await _getToken();
    final response = await apiClient.get(
      endpoint: '/payments/communities/$communityId/balance',
      token: token,
    );
    return BalanceModel.fromJson(response);
  }

  @override
  Future<VendingAddressModel> getVendingAddress() async {
    final token = await _getToken();
    final response = await apiClient.get(
      endpoint: '/payments/vending-address',
      token: token,
    );
    return VendingAddressModel.fromJson(response);
  }
}

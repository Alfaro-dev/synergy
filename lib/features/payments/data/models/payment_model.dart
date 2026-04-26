import '../../domain/entities/payment.dart';

class BalanceModel extends Balance {
  const BalanceModel({
    required super.balanceWei,
    required super.communityId,
  });

  factory BalanceModel.fromJson(Map<String, dynamic> json) {
    return BalanceModel(
      balanceWei: json['balance_wei'] as String,
      communityId: json['community_id'] as String,
    );
  }
}

class VendingAddressModel extends VendingAddress {
  const VendingAddressModel({required super.address});

  factory VendingAddressModel.fromJson(Map<String, dynamic> json) {
    return VendingAddressModel(address: json['address'] as String);
  }
}

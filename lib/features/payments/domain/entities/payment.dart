import 'package:equatable/equatable.dart';

class Balance extends Equatable {
  const Balance({
    required this.balanceWei,
    required this.communityId,
  });

  final String balanceWei;
  final String communityId;

  @override
  List<Object?> get props => [balanceWei, communityId];
}

class VendingAddress extends Equatable {
  const VendingAddress({required this.address});

  final String address;

  @override
  List<Object?> get props => [address];
}

import 'package:equatable/equatable.dart';
import '../../domain/entities/payment.dart';

sealed class PaymentsState extends Equatable {
  const PaymentsState();

  @override
  List<Object?> get props => [];
}

final class PaymentsInitial extends PaymentsState {
  const PaymentsInitial();
}

final class PaymentsLoading extends PaymentsState {
  const PaymentsLoading();
}

final class PaymentsBalanceLoaded extends PaymentsState {
  const PaymentsBalanceLoaded({required this.balance});

  @override
  List<Object?> get props => [balance];

  final Balance balance;
}

final class PaymentsVendingAddressLoaded extends PaymentsState {
  const PaymentsVendingAddressLoaded({required this.address});

  @override
  List<Object?> get props => [address];

  final VendingAddress address;
}

final class PaymentsError extends PaymentsState {
  const PaymentsError({required this.message});

  @override
  List<Object?> get props => [message];

  final String message;
}

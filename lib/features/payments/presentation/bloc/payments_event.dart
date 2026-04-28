import 'package:equatable/equatable.dart';

sealed class PaymentsEvent extends Equatable {
  const PaymentsEvent();

  @override
  List<Object?> get props => [];
}

final class PaymentsBalanceRequested extends PaymentsEvent {
  const PaymentsBalanceRequested({required this.communityId});
  final String communityId;
}

final class PaymentsVendingAddressRequested extends PaymentsEvent {
  const PaymentsVendingAddressRequested();
}

final class PaymentsErrorDismissed extends PaymentsEvent {
  const PaymentsErrorDismissed();
}

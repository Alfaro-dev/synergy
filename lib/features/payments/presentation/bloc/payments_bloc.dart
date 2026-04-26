import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/payments_repository.dart';
import 'payments_event.dart';
import 'payments_state.dart';

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  PaymentsBloc({required this.repository}) : super(const PaymentsInitial()) {
    on<PaymentsBalanceRequested>(_onBalanceRequested);
    on<PaymentsVendingAddressRequested>(_onVendingAddressRequested);
  }

  final PaymentsRepository repository;

  Future<void> _onBalanceRequested(
    PaymentsBalanceRequested event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(const PaymentsLoading());
    try {
      final balance = await repository.getBalance(event.communityId);
      emit(PaymentsBalanceLoaded(balance: balance));
    } on AppException catch (e) {
      emit(PaymentsError(message: e.message));
    }
  }

  Future<void> _onVendingAddressRequested(
    PaymentsVendingAddressRequested event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(const PaymentsLoading());
    try {
      final address = await repository.getVendingAddress();
      emit(PaymentsVendingAddressLoaded(address: address));
    } on AppException catch (e) {
      emit(PaymentsError(message: e.message));
    }
  }
}

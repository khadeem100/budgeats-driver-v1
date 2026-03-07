import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/repositories/withdrawal_repository.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'finances_state.dart';

class FinancesNotifier extends StateNotifier<FinancesState> {
  FinancesNotifier() : super(const FinancesState());

  final WithdrawalRepository _repo = WithdrawalRepository();

  /// Refresh the user profile stored in LocalStorage so wallet balance is current everywhere
  Future<void> _refreshUserProfile() async {
    final response = await userRepository.getProfileDetails();
    response.when(
      success: (data) {
        LocalStorage.setUser(data.data);
      },
      failure: (_, __) {},
    );
  }

  Future<void> fetchBalance() async {
    state = state.copyWith(isLoadingBalance: true);
    final result = await _repo.getBalance();
    result.when(
      success: (data) {
        state = state.copyWith(
          isLoadingBalance: false,
          balanceSrd: (data['balance_srd'] as num?)?.toDouble() ?? 0,
          balanceEur: (data['balance_eur'] as num?)?.toDouble() ?? 0,
          exchangeRate: (data['exchange_rate'] as num?)?.toDouble() ?? 0,
          bankName: data['bank_name'] as String?,
          bankAccountNumber: data['bank_account_number'] as String?,
          bankAccountHolder: data['bank_account_holder'] as String?,
          bankAccountCurrency: data['bank_account_currency'] as String?,
        );
      },
      failure: (error, statusCode) {
        state = state.copyWith(isLoadingBalance: false);
      },
    );
  }

  Future<void> fetchHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    final result = await _repo.getWithdrawalHistory();
    result.when(
      success: (data) {
        state = state.copyWith(
          isLoadingHistory: false,
          withdrawals: data,
        );
      },
      failure: (error, statusCode) {
        state = state.copyWith(isLoadingHistory: false);
      },
    );
  }

  Future<void> requestWithdrawal({
    required BuildContext context,
    double? amount,
  }) async {
    if (state.balanceSrd <= 0) {
      AppHelpers.showCheckTopSnackBar(
        context,
        AppHelpers.getTranslation(TrKeys.insufficientBalance),
      );
      return;
    }
    state = state.copyWith(isWithdrawing: true);
    final result = await _repo.requestWithdrawal(amount: amount);
    result.when(
      success: (data) {
        state = state.copyWith(isWithdrawing: false);
        AppHelpers.showCheckTopSnackBarInfo(
          context,
          AppHelpers.getTranslation(TrKeys.withdrawalRequested),
        );
        fetchBalance();
        fetchHistory();
        _refreshUserProfile();
      },
      failure: (error, statusCode) {
        state = state.copyWith(isWithdrawing: false);
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.getTranslation(error),
        );
      },
    );
  }
}

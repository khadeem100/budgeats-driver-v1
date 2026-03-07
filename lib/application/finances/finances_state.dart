import 'package:flutter/foundation.dart';

@immutable
class FinancesState {
  final bool isLoadingBalance;
  final bool isLoadingHistory;
  final bool isWithdrawing;
  final double balanceSrd;
  final double balanceEur;
  final double exchangeRate;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountHolder;
  final String? bankAccountCurrency;
  final List<dynamic> withdrawals;

  const FinancesState({
    this.isLoadingBalance = false,
    this.isLoadingHistory = false,
    this.isWithdrawing = false,
    this.balanceSrd = 0,
    this.balanceEur = 0,
    this.exchangeRate = 0,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountHolder,
    this.bankAccountCurrency,
    this.withdrawals = const [],
  });

  FinancesState copyWith({
    bool? isLoadingBalance,
    bool? isLoadingHistory,
    bool? isWithdrawing,
    double? balanceSrd,
    double? balanceEur,
    double? exchangeRate,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? bankAccountCurrency,
    List<dynamic>? withdrawals,
  }) {
    return FinancesState(
      isLoadingBalance: isLoadingBalance ?? this.isLoadingBalance,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isWithdrawing: isWithdrawing ?? this.isWithdrawing,
      balanceSrd: balanceSrd ?? this.balanceSrd,
      balanceEur: balanceEur ?? this.balanceEur,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      bankAccountCurrency: bankAccountCurrency ?? this.bankAccountCurrency,
      withdrawals: withdrawals ?? this.withdrawals,
    );
  }
}

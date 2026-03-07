import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:driver/application/finances/finances_provider.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/styles/style.dart';

@RoutePage()
class FinancesPage extends ConsumerStatefulWidget {
  const FinancesPage({super.key});

  @override
  ConsumerState<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends ConsumerState<FinancesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(financesProvider.notifier).fetchBalance();
      ref.read(financesProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financesProvider);
    final bool isLtr = LocalStorage.getLangLtr();

    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Style.greyColor,
        body: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(financesProvider.notifier).fetchBalance();
                  await ref.read(financesProvider.notifier).fetchHistory();
                },
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  children: [
                    _buildBalanceCard(state),
                    16.verticalSpace,
                    _buildExchangeRateCard(state),
                    16.verticalSpace,
                    _buildBankInfoCard(state),
                    16.verticalSpace,
                    _buildWithdrawButton(context, state),
                    24.verticalSpace,
                    _buildWithdrawalHistoryHeader(),
                    12.verticalSpace,
                    if (state.isLoadingHistory)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.r),
                          child: const CircularProgressIndicator(color: Style.primaryColor),
                        ),
                      )
                    else if (state.withdrawals.isEmpty)
                      _buildEmptyHistory()
                    else
                      ...state.withdrawals.map((w) => _buildWithdrawalItem(w)),
                    80.verticalSpace,
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniStartFloat,
        floatingActionButton: const PopButton(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return CustomAppBar(
      bottomPadding: 16.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Text(
              AppHelpers.getTranslation(TrKeys.finances),
              style: Style.interSemi(size: 22.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(dynamic state) {
    return Container(
      decoration: BoxDecoration(
        color: Style.black,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(20.r),
      child: state.isLoadingBalance
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(20.r),
                child: const CircularProgressIndicator(color: Style.primaryColor),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.walletBalance),
                  style: Style.interNormal(size: 14.sp, color: Style.textGrey),
                ),
                12.verticalSpace,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'SRD',
                      style: Style.interNormal(size: 16.sp, color: Style.primaryColor),
                    ),
                    8.horizontalSpace,
                    Text(
                      NumberFormat('#,##0.00').format(state.balanceSrd),
                      style: Style.interSemi(size: 32.sp, color: Style.white),
                    ),
                  ],
                ),
                8.verticalSpace,
                Container(
                  height: 1,
                  color: Style.textGrey.withOpacity(0.3),
                ),
                8.verticalSpace,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'EUR',
                      style: Style.interNormal(size: 14.sp, color: Style.primaryColor),
                    ),
                    8.horizontalSpace,
                    Text(
                      NumberFormat('#,##0.00').format(state.balanceEur),
                      style: Style.interSemi(size: 22.sp, color: Style.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildExchangeRateCard(dynamic state) {
    return Container(
      decoration: BoxDecoration(
        color: Style.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(16.r),
      child: Row(
        children: [
          Icon(FlutterRemix.exchange_line, size: 24.r, color: Style.primaryColor),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.exchangeRate),
                  style: Style.interNormal(size: 12.sp, color: Style.textGrey),
                ),
                Text(
                  '1 EUR = ${NumberFormat('#,##0.00').format(state.exchangeRate)} SRD',
                  style: Style.interSemi(size: 14.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoCard(dynamic state) {
    final hasBankInfo = state.bankName != null && state.bankName!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Style.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FlutterRemix.bank_line, size: 24.r, color: Style.primaryColor),
              12.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.bankAccount),
                style: Style.interSemi(size: 14.sp),
              ),
            ],
          ),
          12.verticalSpace,
          if (hasBankInfo) ...[
            _bankInfoRow('Bank', state.bankName ?? ''),
            6.verticalSpace,
            _bankInfoRow('Account', state.bankAccountNumber ?? ''),
            6.verticalSpace,
            _bankInfoRow('Holder', state.bankAccountHolder ?? ''),
            6.verticalSpace,
            _bankInfoRow('Currency', (state.bankAccountCurrency ?? 'SRD').toString().toUpperCase()),
          ] else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                AppHelpers.getTranslation(TrKeys.noBankAccount),
                style: Style.interNormal(size: 13.sp, color: Style.textGrey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bankInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80.w,
          child: Text(label, style: Style.interNormal(size: 12.sp, color: Style.textGrey)),
        ),
        Expanded(
          child: Text(value, style: Style.interNormal(size: 13.sp)),
        ),
      ],
    );
  }

  Widget _buildWithdrawButton(BuildContext context, dynamic state) {
    final hasBankInfo = state.bankName != null && state.bankName!.isNotEmpty;
    final hasBalance = state.balanceSrd > 0;

    return CustomButton(
      isLoading: state.isWithdrawing,
      title: AppHelpers.getTranslation(TrKeys.withdrawFunds),
      background: (hasBankInfo && hasBalance) ? Style.primaryColor : Style.textGrey,
      textColor: Style.black,
      onPressed: (hasBankInfo && hasBalance)
          ? () => _showWithdrawDialog(context, state)
          : () {
              AppHelpers.showCheckTopSnackBar(
                context,
                hasBankInfo
                    ? AppHelpers.getTranslation(TrKeys.insufficientBalance)
                    : AppHelpers.getTranslation(TrKeys.noBankAccount),
              );
            },
    );
  }

  void _showWithdrawDialog(BuildContext context, dynamic state) {
    final amountController = TextEditingController();
    String? amountError;

    AppHelpers.showAlertDialog(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            decoration: BoxDecoration(
              color: Style.white,
              borderRadius: BorderRadius.circular(10.r),
            ),
            padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FlutterRemix.wallet_3_line,
                  size: 48.r,
                  color: Style.primaryColor,
                ),
                12.verticalSpace,
                Text(
                  AppHelpers.getTranslation(TrKeys.requestWithdrawal),
                  style: Style.interSemi(size: 18.sp),
                  textAlign: TextAlign.center,
                ),
                8.verticalSpace,
                Text(
                  'Balance: SRD ${NumberFormat('#,##0.00').format(state.balanceSrd)}',
                  style: Style.interNormal(size: 14.sp, color: Style.textGrey),
                ),
                20.verticalSpace,
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: Style.interNormal(size: 16.sp),
                  decoration: InputDecoration(
                    labelText: AppHelpers.getTranslation(TrKeys.withdrawalAmount),
                    labelStyle: Style.interNormal(size: 14.sp, color: Style.textGrey),
                    prefixText: 'SRD ',
                    prefixStyle: Style.interSemi(size: 14.sp, color: Style.primaryColor),
                    errorText: amountError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: Style.primaryColor, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                  ),
                ),
                8.verticalSpace,
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      amountController.text = state.balanceSrd.toStringAsFixed(2);
                    },
                    child: Text(
                      AppHelpers.getTranslation(TrKeys.withdrawAll),
                      style: Style.interNormal(size: 13.sp, color: Style.primaryColor),
                    ),
                  ),
                ),
                16.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        title: AppHelpers.getTranslation(TrKeys.cancel),
                        background: Style.greyColor,
                        textColor: Style.black,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    10.horizontalSpace,
                    Expanded(
                      child: CustomButton(
                        title: AppHelpers.getTranslation(TrKeys.confirmation),
                        onPressed: () {
                          final text = amountController.text.trim();
                          final amount = double.tryParse(text);
                          if (text.isEmpty || amount == null || amount <= 0) {
                            setDialogState(() {
                              amountError = AppHelpers.getTranslation(TrKeys.cannotBeEmpty);
                            });
                            return;
                          }
                          if (amount > state.balanceSrd) {
                            setDialogState(() {
                              amountError = AppHelpers.getTranslation(TrKeys.insufficientBalance);
                            });
                            return;
                          }
                          Navigator.pop(context);
                          ref.read(financesProvider.notifier).requestWithdrawal(
                            context: context,
                            amount: amount,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWithdrawalHistoryHeader() {
    return Text(
      AppHelpers.getTranslation(TrKeys.withdrawalHistory),
      style: Style.interSemi(size: 16.sp),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32.h),
        child: Column(
          children: [
            Icon(FlutterRemix.file_list_3_line, size: 48.r, color: Style.textGrey),
            12.verticalSpace,
            Text(
              AppHelpers.getTranslation(TrKeys.noWithdrawals),
              style: Style.interNormal(size: 14.sp, color: Style.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalItem(dynamic withdrawal) {
    final Map<String, dynamic> w = Map<String, dynamic>.from(withdrawal);
    final status = (w['status'] ?? 'pending').toString();
    final amountSrd = (w['amount_srd'] as num?)?.toDouble() ?? 0;
    final amountEur = (w['amount_eur'] as num?)?.toDouble() ?? 0;
    final payoutCurrency = (w['payout_currency'] ?? 'SRD').toString();
    final payoutAmount = (w['payout_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = w['created_at'] != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(w['created_at']).toLocal())
        : '';
    final adminNote = w['admin_note'] as String?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = Style.greenColor;
        statusIcon = FlutterRemix.check_double_line;
        break;
      case 'rejected':
        statusColor = Style.redColor;
        statusIcon = FlutterRemix.close_circle_line;
        break;
      default:
        statusColor = Style.pendingDark;
        statusIcon = FlutterRemix.time_line;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Style.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 20.r, color: statusColor),
                  8.horizontalSpace,
                  Text(
                    status.toUpperCase(),
                    style: Style.interSemi(size: 12.sp, color: statusColor),
                  ),
                ],
              ),
              Text(
                '#${w['id'] ?? ''}',
                style: Style.interNormal(size: 12.sp, color: Style.textGrey),
              ),
            ],
          ),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SRD ${NumberFormat('#,##0.00').format(amountSrd)}',
                    style: Style.interSemi(size: 16.sp),
                  ),
                  Text(
                    'EUR ${NumberFormat('#,##0.00').format(amountEur)}',
                    style: Style.interNormal(size: 12.sp, color: Style.textGrey),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Payout: $payoutCurrency ${NumberFormat('#,##0.00').format(payoutAmount)}',
                    style: Style.interNormal(size: 12.sp, color: Style.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          6.verticalSpace,
          Text(
            createdAt,
            style: Style.interNormal(size: 11.sp, color: Style.textGrey),
          ),
          if (adminNote != null && adminNote.isNotEmpty) ...[
            6.verticalSpace,
            Text(
              'Note: $adminNote',
              style: Style.interNormal(size: 11.sp, color: Style.redColor),
            ),
          ],
        ],
      ),
    );
  }
}

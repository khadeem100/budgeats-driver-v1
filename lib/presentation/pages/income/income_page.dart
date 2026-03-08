import 'package:auto_route/annotations.dart';
import 'package:charts_flutter/flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:driver/application/statistics/statistics_provider.dart';
import 'package:driver/application/statistics/statistics_state.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/models/models.dart';

import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/styles/style.dart';
import 'app_bar_screen.dart';
import 'statistics_screen.dart';
import 'widgets/income_item.dart';
@RoutePage()
class IncomePage extends ConsumerStatefulWidget {
  const IncomePage({super.key});

  @override
  ConsumerState<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends ConsumerState<IncomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isWalletLoading = true;
  List<WalletHistoryData> _walletHistories = [];

  final _tabs = [
    Tab(
      child: Text(
        AppHelpers.getTranslation(TrKeys.today),
      ),
    ),
    Tab(
      child: Text(
        AppHelpers.getTranslation(TrKeys.weekly),
      ),
    ),
    Tab(
      child: Text(
        AppHelpers.getTranslation(TrKeys.monthly),
      ),
    ),
  ];

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        ref.read(statisticsProvider.notifier).fetchStatistics(
            startTime: DateTime.now(), endTime: DateTime.now());
      } else if (_tabController.index == 1) {
        ref.read(statisticsProvider.notifier).fetchStatistics(
            startTime: DateTime.now(),
            endTime: DateTime.now().subtract(const Duration(days: 7)));
      } else {
        ref.read(statisticsProvider.notifier).fetchStatistics(
            startTime: DateTime.now(),
            endTime: DateTime.now().subtract(const Duration(days: 30)));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        ref.read(statisticsProvider.notifier).fetchStatistics(
            startTime: DateTime.now(), endTime: DateTime.now());
        _fetchWalletHistories();
      },
    );
    super.initState();
  }

  Future<void> _fetchWalletHistories() async {
    setState(() {
      _isWalletLoading = true;
    });

    final response = await userRepository.getWalletHistories(perPage: 20);

    response.when(
      success: (data) {
        if (mounted) {
          setState(() {
            _walletHistories = data.data;
            _isWalletLoading = false;
          });
        }
      },
      failure: (failure, status) {
        if (mounted) {
          setState(() {
            _walletHistories = [];
            _isWalletLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statisticsProvider);
    return Scaffold(
      backgroundColor: Style.greyColor,
      body: Column(
        children: [
          const AbbBarScreen(),
          16.verticalSpace,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  right: 16.w,
                  left: 16.w,
                  bottom: MediaQuery.paddingOf(context).bottom + 56.h),
              child: Column(
                children: [
                  CustomTabBar(
                    tabController: _tabController,
                    tabs: _tabs,
                  ),
                  24.verticalSpace,
                  _orderPrices(context, state),
                  // TitleAndIcon(
                  //   title: AppHelpers.getTranslation(TrKeys.remittanceIncome),
                  // ),
                  // 12.verticalSpace,
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.servicePrice),
                  //   price: "\$0",
                  // ),
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.tax),
                  //   price: "\$2",
                  // ),
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.shippingCost),
                  //   price: "\$500",
                  // ),
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.adminBenefit),
                  //   price: "\$5.8",
                  // ),
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.yourBenefit),
                  //   price: "\$560",
                  // ),
                  // 24.verticalSpace,
                  TitleAndIcon(
                    title: AppHelpers.getTranslation(
                        TrKeys.deliverymanTransactions),
                  ),
                  12.verticalSpace,
                  IncomeItem(
                    title: AppHelpers.getTranslation(TrKeys.wallet),
                    price: AppHelpers.numberFormat(
                        number:
                            LocalStorage.getUser()?.wallet?.price ??
                                0),
                  ),
                  IncomeItem(
                    title: AppHelpers.getTranslation(TrKeys.rating),
                    price:
                        "${LocalStorage.getUser()?.rate?.toStringAsFixed(1) ?? 0}",
                  ),
                  24.verticalSpace,
                  TitleAndIcon(title: 'Wallet transactions'),
                  12.verticalSpace,
                  _buildWalletHistorySection(),
                  24.verticalSpace,
                  // TitleAndIcon(
                  //   title: AppHelpers.getTranslation(TrKeys.payment),
                  // ),
                  // 12.verticalSpace,
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.grossProfit),
                  //   price: "\$580",
                  // ),
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.earningsWallet),
                  //   price: "\$100",
                  // ),
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.paid),
                  //   price: "\$0",
                  // ),
                  // IncomeItem(
                  //   title: AppHelpers.getTranslation(TrKeys.paidCourier),
                  //   price: "\$560",
                  //   isBlack: true,
                  // ),
                  // 24.verticalSpace,
                  StatisticsScreen(
                      totalOrders: (state.countData?.data?.totalCount ?? 0)
                          .toString(),
                      todayOrders: (state.countData?.data?.totalTodayCount ?? 0)
                          .toString(),
                      acceptedOrders: (state
                                  .countData?.data?.totalAcceptedCount ??
                              0)
                          .toString(),
                      rejectedOrders: (state
                                  .countData?.data?.totalCanceledCount ??
                              0)
                          .toString(),
                      doneOrders: (state.countData?.data?.totalDeliveredCount ??
                              0)
                          .toString(),
                      canceledOrders:
                          (state
                                      .countData?.data?.totalNewCount ??
                                  0)
                              .toString(),
                      acceptedPer:
                          "${((state.countData?.data?.totalAcceptedCount ?? 0) / (state.countData?.data?.totalCount ?? 1) * 100).toStringAsFixed(1)}%",
                      rejectedPer:
                          "${((state.countData?.data?.totalCanceledCount ?? 0) / (state.countData?.data?.totalCount ?? 1) * 100).toStringAsFixed(1)}%",
                      donePer:
                          "${((state.countData?.data?.totalDeliveredCount ?? 0) / (state.countData?.data?.totalCount ?? 1) * 100).toStringAsFixed(1)}%",
                      canceledPer:
                          "${((state.countData?.data?.totalNewCount ?? 0) / (state.countData?.data?.totalCount ?? 1) * 100).toStringAsFixed(1)}%"),
                  32.verticalSpace,
                  _chart(state),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const PopButton(),
    );
  }

  Widget _buildWalletHistorySection() {
    if (_isWalletLoading) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Style.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.all(20.r),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_walletHistories.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Style.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.all(20.r),
        child: Text(
          'No transactions yet',
          style: Style.interNormal(size: 14.sp, color: Style.black),
        ),
      );
    }

    return Column(
      children: _walletHistories
          .map(
            (item) => GestureDetector(
              onTap: () => _showTransactionDetails(item),
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 4.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: Style.white,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 42.r,
                      width: 42.r,
                      decoration: BoxDecoration(
                        color: _isCredit(item)
                            ? Style.primaryColor.withOpacity(0.12)
                            : Colors.deepOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        _isCredit(item)
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: _isCredit(item)
                            ? Style.primaryColor
                            : Colors.deepOrange,
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _transactionTitle(item),
                            style: Style.interSemi(size: 14.sp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          4.verticalSpace,
                          Text(
                            item.createdAt ?? item.status ?? '',
                            style: Style.interRegular(
                              size: 12.sp,
                              color: Style.textGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    8.horizontalSpace,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _transactionAmount(item),
                          style: Style.interSemi(
                            size: 14.sp,
                            color: _isCredit(item)
                                ? Style.primaryColor
                                : Colors.deepOrange,
                          ),
                        ),
                        4.verticalSpace,
                        Text(
                          'View',
                          style: Style.interRegular(
                            size: 12.sp,
                            color: Style.textGrey,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  bool _isCredit(WalletHistoryData item) => item.type == 'topup';

  String _transactionTitle(WalletHistoryData item) {
    final note = item.note ?? '';

    if (note.contains('Delivery earnings')) {
      return 'Delivery earnings';
    }

    if (item.type == 'withdraw') {
      return 'Withdrawal request';
    }

    return note.isNotEmpty ? note : 'Wallet transaction';
  }

  String _transactionAmount(WalletHistoryData item) {
    final prefix = _isCredit(item) ? '+' : '-';
    return '$prefix${AppHelpers.numberFormat(number: item.price ?? 0)}';
  }

  void _showTransactionDetails(WalletHistoryData item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Style.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Style.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.all(20.r),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Style.borderColor,
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                ),
                20.verticalSpace,
                Text(
                  _transactionTitle(item),
                  style: Style.interSemi(size: 18.sp),
                ),
                16.verticalSpace,
                _detailRow('Amount', _transactionAmount(item)),
                _detailRow('Status', item.status ?? 'unknown'),
                _detailRow('Type', item.type ?? 'unknown'),
                _detailRow('Created', item.createdAt ?? '-'),
                _detailRow('Transaction ID', item.transactionId?.toString() ?? '-'),
                _detailRow('Reference', item.uuid ?? '-'),
                _detailRow('Note', item.note?.isNotEmpty == true ? item.note! : '-'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              label,
              style: Style.interRegular(size: 13.sp, color: Style.textGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Style.interSemi(size: 13.sp, color: Style.black),
            ),
          ),
        ],
      ),
    );
  }

  Column _chart(StatisticsState state) {
    return  Column(
      children: [
        TitleAndIcon(title: AppHelpers.getTranslation(TrKeys.earningsChart)),
        16.verticalSpace,
        Container(
            width: double.infinity,
            height: 300.h,
            decoration: BoxDecoration(
              color: Style.white,
              borderRadius: BorderRadius.circular(10.r),
            ),
            padding: EdgeInsets.all(16.r),
            child: BarChart(
              state.list,
              animate: true,
              vertical: false,
              animationDuration: const Duration(seconds: 1),
              defaultRenderer: BarRendererConfig(
                  cornerStrategy: const ConstCornerStrategy(6)),
            )),
        32.verticalSpace,
      ],
    );
  }

  Column _orderPrices(BuildContext context, StatisticsState state) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Style.white,
            borderRadius: BorderRadius.circular(10.r),
          ),
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppHelpers.getTranslation(TrKeys.orderPrice),
                style: Style.interNormal(
                    size: 14.sp, color: Style.black, letterSpacing: -0.3),
              ),
              16.verticalSpace,
              Text(
                AppHelpers.numberFormat(
                    number: state.countData?.data?.lastOrderTotalPrice ?? 0),
                style: Style.interSemi(
                    size: 32.sp, color: Style.black, letterSpacing: -0.3),
              ),
              4.verticalSpace,
              RichText(
                  text: TextSpan(
                      text: AppHelpers.getTranslation(TrKeys.lastIncome),
                      style: Style.interNormal(
                          size: 12.sp,
                          color: Style.black,
                          letterSpacing: -0.3),
                      children: [
                    TextSpan(
                      text: AppHelpers.numberFormat(
                          number: state.countData?.data?.lastOrderIncome ?? 0),
                      style: Style.interSemi(
                          size: 12.sp,
                          color: Style.black,
                          letterSpacing: -0.3),
                    )
                  ])),
            ],
          ),
        ),
        // 10.verticalSpace,
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   children: [
        //     Container(
        //       width: (MediaQuery.sizeOf(context).width - 40) / 2,
        //       decoration: BoxDecoration(
        //         color: Style.blackColor,
        //         borderRadius: BorderRadius.circular(10.r),
        //       ),
        //       padding: EdgeInsets.all(16.r),
        //       child: Column(
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: [
        //           Text(
        //             AppHelpers.getTranslation(TrKeys.restaurantRevenue),
        //             style: Style.interNormal(
        //                 size: 12.sp, color: Style.white, letterSpacing: -0.3),
        //           ),
        //           Text(
        //             "\$79",
        //             style: Style.interSemi(
        //                 size: 22.sp, color: Style.white, letterSpacing: -0.3),
        //           )
        //         ],
        //       ),
        //     ),
        //     Container(
        //       width: (MediaQuery.sizeOf(context).width - 40) / 2,
        //       decoration: BoxDecoration(
        //         color: Style.blackColor,
        //         borderRadius: BorderRadius.circular(10.r),
        //       ),
        //       padding: EdgeInsets.all(16.r),
        //       child: Column(
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: [
        //           Text(
        //             AppHelpers.getTranslation(TrKeys.fMRevenue),
        //             style: Style.interNormal(
        //                 size: 12.sp, color: Style.white, letterSpacing: -0.3),
        //           ),
        //           Text(
        //             "\$7",
        //             style: Style.interSemi(
        //                 size: 22.sp, color: Style.white, letterSpacing: -0.3),
        //           )
        //         ],
        //       ),
        //     )
        //   ],
        // ),
        32.verticalSpace,
      ],
    );
  }
}

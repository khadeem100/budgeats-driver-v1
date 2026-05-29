import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:percent_indicator/percent_indicator.dart';
import 'package:driver/application/providers.dart';
import 'package:driver/application/order/order_provider.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import '../../../infrastructure/models/data/order_detail.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/styles/style.dart';

/// Calculates the distance in km between two LatLng points using the Haversine formula.
double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0; // Earth radius in km
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _deg2rad(double deg) => deg * (pi / 180);

/// Data class holding an order plus computed suggestion metadata.
class SuggestedOrder {
  final OrderDetailData order;
  final double driverToShopKm;
  final double shopToCustomerKm;
  final double totalKm;
  final bool isFastest;

  SuggestedOrder({
    required this.order,
    required this.driverToShopKm,
    required this.shopToCustomerKm,
    required this.totalKm,
    this.isFastest = false,
  });

  SuggestedOrder copyWith({bool? isFastest}) => SuggestedOrder(
        order: order,
        driverToShopKm: driverToShopKm,
        shopToCustomerKm: shopToCustomerKm,
        totalKm: totalKm,
        isFastest: isFastest ?? this.isFastest,
      );
}

/// Slider popup that shows multiple incoming orders.
/// Driver can swipe between them, accept or decline each one.
/// Orders are sorted by total distance; the fastest is tagged.
class PushOrderSlider extends ConsumerStatefulWidget {
  /// Current pending orders, managed by the parent via ValueNotifier.
  final ValueNotifier<List<OrderDetailData>> pendingOrders;

  /// Called when the dialog should be closed (no more orders).
  final VoidCallback onClose;

  /// Driver's current location for distance calculation.
  final LatLng driverLocation;

  const PushOrderSlider({
    super.key,
    required this.pendingOrders,
    required this.onClose,
    required this.driverLocation,
  });

  @override
  ConsumerState<PushOrderSlider> createState() => _PushOrderSliderState();
}

class _PushOrderSliderState extends ConsumerState<PushOrderSlider> {
  late PageController _pageController;
  int _currentPage = 0;

  /// Per-order countdown timers. Key = orderId.
  final Map<int, Timer> _timers = {};
  final Map<int, int> _countdowns = {};
  final Map<int, Timer> _availabilityTimers = {};
  final Set<int> _closedOrders = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Start timers for all initial orders
    for (final order in widget.pendingOrders.value) {
      _ensureTimer(order);
    }
    widget.pendingOrders.addListener(_onOrdersChanged);
  }

  void _onOrdersChanged() {
    if (!mounted) return;
    // Start timers for any new orders
    for (final order in widget.pendingOrders.value) {
      _ensureTimer(order);
    }
    setState(() {});
    if (widget.pendingOrders.value.isEmpty) {
      widget.onClose();
    }
  }

  void _ensureTimer(OrderDetailData order) {
    final id = order.id;
    if (id == null || _timers.containsKey(id)) return;

    final acceptanceTime = AppHelpers.getAppDeliveryTime();
    _countdowns[id] = acceptanceTime;

    _timers[id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = (_countdowns[id] ?? 0) - 1;
      _countdowns[id] = remaining;
      if (remaining <= 0) {
        timer.cancel();
        _onOrderTimeout(id);
      }
      if (mounted) setState(() {});
    });

    // Start availability watcher (check if order got assigned)
    _availabilityTimers[id] = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _closedOrders.contains(id)) return;
      final response = await orderRepository.showOrders(id);
      response.when(
        success: (data) {
          final o = data.data;
          final assigned = o?.deliveryman != null;
          final closedStatus = ['canceled', 'cancelled', 'delivered', 'rejected', 'rejected_by_admin']
              .contains((o?.status ?? '').toLowerCase());
          if (assigned || closedStatus) {
            _removeOrder(id, addToAvailable: false);
          }
        },
        failure: (_, __) {
          _removeOrder(id, addToAvailable: false);
        },
      );
    });
  }

  void _onOrderTimeout(int orderId) {
    if (_closedOrders.contains(orderId)) return;
    // Move to available orders on timeout
    final order = widget.pendingOrders.value.firstWhere(
      (o) => o.id == orderId,
      orElse: () => OrderDetailData(),
    );
    if (order.id != null) {
      ref.read(orderProvider.notifier).upsertAvailableOrder(order);
    }
    _removeOrder(orderId, addToAvailable: false);
  }

  void _removeOrder(int orderId, {bool addToAvailable = false}) {
    _closedOrders.add(orderId);
    _timers[orderId]?.cancel();
    _availabilityTimers[orderId]?.cancel();

    if (addToAvailable) {
      final order = widget.pendingOrders.value.firstWhere(
        (o) => o.id == orderId,
        orElse: () => OrderDetailData(),
      );
      if (order.id != null) {
        ref.read(orderProvider.notifier).upsertAvailableOrder(order);
      }
    }

    widget.pendingOrders.value = List.from(widget.pendingOrders.value)
      ..removeWhere((o) => o.id == orderId);

    if (widget.pendingOrders.value.isEmpty) {
      widget.onClose();
    } else {
      if (_currentPage >= widget.pendingOrders.value.length) {
        _currentPage = widget.pendingOrders.value.length - 1;
      }
      if (mounted) setState(() {});
    }
  }

  List<SuggestedOrder> _buildSuggestions() {
    final driverLat = widget.driverLocation.latitude;
    final driverLng = widget.driverLocation.longitude;

    List<SuggestedOrder> suggestions = [];
    for (final order in widget.pendingOrders.value) {
      final shopLat = double.tryParse(order.shop?.location?.latitude ?? '0') ?? 0;
      final shopLng = double.tryParse(order.shop?.location?.longitude ?? '0') ?? 0;
      final custLat = double.tryParse(order.location?.latitude ?? '0') ?? 0;
      final custLng = double.tryParse(order.location?.longitude ?? '0') ?? 0;

      final driverToShop = _haversineKm(driverLat, driverLng, shopLat, shopLng);
      final shopToCustomer = _haversineKm(shopLat, shopLng, custLat, custLng);

      suggestions.add(SuggestedOrder(
        order: order,
        driverToShopKm: driverToShop,
        shopToCustomerKm: shopToCustomer,
        totalKm: driverToShop + shopToCustomer,
      ));
    }

    // Sort by total distance (nearest first)
    suggestions.sort((a, b) => a.totalKm.compareTo(b.totalKm));

    // Tag the fastest one
    if (suggestions.isNotEmpty) {
      suggestions[0] = suggestions[0].copyWith(isFastest: true);
    }

    return suggestions;
  }

  @override
  void dispose() {
    widget.pendingOrders.removeListener(_onOrdersChanged);
    _pageController.dispose();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    for (final timer in _availabilityTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _buildSuggestions();
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 540.h,
      width: double.infinity,
      color: Style.transparent,
      child: Column(
        children: [
          // Page indicator dots + order count
          if (suggestions.length > 1)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Style.white,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${suggestions.length} orders',
                      style: Style.interSemi(size: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
          // Slider
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: suggestions.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: _OrderCard(
                    suggestion: suggestion,
                    countdown: _countdowns[suggestion.order.id] ?? 0,
                    onAccept: () => _acceptOrder(suggestion.order),
                    onDecline: () => _declineOrder(suggestion.order),
                  ),
                );
              },
            ),
          ),
          // Page dots
          if (suggestions.length > 1)
            Padding(
              padding: EdgeInsets.only(top: 8.h, bottom: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  suggestions.length,
                  (i) => Container(
                    width: i == _currentPage ? 20.w : 8.w,
                    height: 8.h,
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    decoration: BoxDecoration(
                      color: i == _currentPage ? Style.primaryColor : Style.shimmerBase,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _acceptOrder(OrderDetailData order) async {
    final orderId = order.id;
    if (orderId == null) return;

    final ImageCropperMarker image = ImageCropperMarker();
    // Use actual driver location from the widget, not LocalStorage which may be stale
    final driverLat = widget.driverLocation.latitude;
    final driverLng = widget.driverLocation.longitude;

    ref.read(homeProvider.notifier).goMarket(
      context: context,
      orderId: orderId.toString(),
      order: order,
      setOrder: true,
      onFailure: () {},
      onSuccess: () async {
        if (order.id != null) {
          ref.read(orderProvider.notifier).removeAvailableOrder(order.id!);
          ref.read(orderProvider.notifier).fetchActiveOrders(context);
        }
        // Close the entire popup
        widget.onClose();

        ref.read(homeProvider.notifier).getRoutingAll(
              // ignore: use_build_context_synchronously
              context: context,
              start: LatLng(driverLat, driverLng),
              end: LatLng(
                double.parse(order.shop?.location?.latitude ?? "0"),
                double.parse(order.shop?.location?.longitude ?? "0"),
              ),
              market: Marker(
                markerId: const MarkerId("Shop"),
                position: LatLng(
                  double.parse(order.shop?.location?.latitude ?? "0"),
                  double.parse(order.shop?.location?.longitude ?? "0"),
                ),
                icon: await image.resizeAndCircle(order.shop?.logoImg ?? "", 120),
              ),
            );
      },
    );
  }

  Future<void> _declineOrder(OrderDetailData order) async {
    final orderId = order.id;
    if (orderId == null) return;

    final response = await orderRepository.declineOrder(orderId);
    response.when(
      success: (_) {
        ref.read(orderProvider.notifier).removeAvailableOrder(orderId);
        _removeOrder(orderId, addToAvailable: false);
      },
      failure: (failure, __) {
        if (mounted) {
          AppHelpers.showCheckTopSnackBar(context, AppHelpers.getTranslation(failure));
        }
      },
    );
  }
}

/// Individual order card inside the slider.
class _OrderCard extends StatelessWidget {
  final SuggestedOrder suggestion;
  final int countdown;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OrderCard({
    required this.suggestion,
    required this.countdown,
    required this.onAccept,
    required this.onDecline,
  });

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final order = suggestion.order;
    final acceptanceTime = AppHelpers.getAppDeliveryTime();

    return Container(
      height: 460.h,
      width: MediaQuery.sizeOf(context).width - 32.w,
      decoration: BoxDecoration(
        color: Style.white,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Timer at the top
          Positioned(
            top: -52.r,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: const BoxDecoration(color: Style.white, shape: BoxShape.circle),
                child: CircularPercentIndicator(
                  radius: 48.r,
                  lineWidth: 12.r,
                  percent: acceptanceTime > 0 ? (countdown / acceptanceTime).clamp(0.0, 1.0) : 0,
                  center: Text(
                    '${countdown.toString().padLeft(2, '0')} s',
                    style: Style.interSemi(size: 18.sp),
                  ),
                  fillColor: Style.transparent,
                  backgroundColor: Style.shimmerBase,
                  progressColor: Style.progressColor,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(top: 64.h, left: 16.w, right: 16.w),
            child: Column(
              children: [
                // Fastest tag
                if (suggestion.isFastest)
                  Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FlutterRemix.flashlight_fill, size: 14.r, color: Style.white),
                        4.horizontalSpace,
                        Text(
                          'Fastest • ${_formatDistance(suggestion.totalKm)}',
                          style: Style.interSemi(size: 12.sp, color: Style.white),
                        ),
                      ],
                    ),
                  ),

                // Distance info row
                Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Style.shimmerBase.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FlutterRemix.navigation_fill, size: 14.r, color: Style.primaryColor),
                      4.horizontalSpace,
                      Text(
                        _formatDistance(suggestion.driverToShopKm),
                        style: Style.interSemi(size: 11.sp),
                      ),
                      8.horizontalSpace,
                      Icon(FlutterRemix.arrow_right_line, size: 14.r),
                      8.horizontalSpace,
                      Icon(FlutterRemix.store_2_fill, size: 14.r, color: Style.primaryColor),
                      4.horizontalSpace,
                      Text(
                        _formatDistance(suggestion.shopToCustomerKm),
                        style: Style.interSemi(size: 11.sp),
                      ),
                      8.horizontalSpace,
                      Text(
                        '= ${_formatDistance(suggestion.totalKm)}',
                        style: Style.interSemi(size: 11.sp, color: Style.primaryColor),
                      ),
                    ],
                  ),
                ),

                // Shop info
                _orderAvatar(order),

                const Spacer(),
                const Divider(color: Style.borderColor),
                8.verticalSpace,

                // Price / delivery fee / payment
                Row(
                  children: [
                    SvgPicture.asset("assets/svg/cutter.svg", width: 18.r),
                    6.horizontalSpace,
                    Text(
                      AppHelpers.numberFormat(number: order.totalPrice ?? 0),
                      style: Style.interSemi(size: 12.sp),
                    ),
                    const Spacer(),
                    Icon(FlutterRemix.takeaway_fill, size: 18.sp),
                    6.horizontalSpace,
                    Text(
                      AppHelpers.numberFormat(number: order.deliveryFee ?? 0),
                      style: Style.interSemi(size: 12.sp),
                    ),
                    const Spacer(),
                    Icon(FlutterRemix.bank_card_2_line, size: 18.sp),
                    6.horizontalSpace,
                    Text(
                      order.transaction?.paymentSystem?.tag ?? "",
                      style: Style.interSemi(size: 12.sp),
                    ),
                  ],
                ),

                8.verticalSpace,
                const Divider(color: Style.borderColor),
                const Spacer(),

                // Accept / Deny buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        title: 'Deny',
                        onPressed: onDecline,
                        background: Style.transparent,
                        borderColor: Style.black,
                        textColor: Style.black,
                      ),
                    ),
                    14.horizontalSpace,
                    Expanded(
                      child: CustomButton(
                        title: AppHelpers.getTranslation(TrKeys.accept),
                        onPressed: onAccept,
                      ),
                    ),
                  ],
                ),
                16.verticalSpace,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderAvatar(OrderDetailData order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shop row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 32.r,
              width: 32.r,
              decoration: const BoxDecoration(color: Style.white, shape: BoxShape.circle),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: "${order.shop?.logoImg}",
                  fit: BoxFit.cover,
                  progressIndicatorBuilder: (context, url, progress) =>
                      ImageShimmer(isCircle: true, size: 32.r),
                  errorWidget: (context, url, error) => Container(
                    height: 32.r,
                    width: 32.r,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Style.greyColor),
                    alignment: Alignment.center,
                    child: const Icon(FlutterRemix.image_line, color: Style.black),
                  ),
                ),
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.shop?.translation?.title ?? "",
                    style: Style.interSemi(size: 14.sp, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  2.verticalSpace,
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Text(
                          '№ ${order.id}',
                          style: Style.interNormal(size: 13.sp, letterSpacing: -0.3),
                        ),
                        const VerticalDivider(),
                        Text(
                          intl.DateFormat("HH:mm").format(DateTime.tryParse(
                                      order.updatedAt ?? DateTime.now().toString())
                                  ?.toLocal() ??
                              DateTime.now()),
                          style: Style.interNormal(size: 13.sp, letterSpacing: -0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Dots connecting shop to customer
        Padding(
          padding: EdgeInsets.only(left: 14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4.r, height: 4.r,
                margin: EdgeInsets.only(bottom: 4.h, top: 4.h),
                decoration: const BoxDecoration(color: Style.tabBarBorderColor, shape: BoxShape.circle),
              ),
              Container(
                width: 4.r, height: 4.r,
                margin: EdgeInsets.only(bottom: 6.h),
                decoration: const BoxDecoration(color: Style.tabBarBorderColor, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
        // Customer row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 32.r,
              width: 32.r,
              decoration: const BoxDecoration(color: Style.white, shape: BoxShape.circle),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: order.user?.img ?? "",
                  fit: BoxFit.cover,
                  progressIndicatorBuilder: (context, url, progress) =>
                      ImageShimmer(isCircle: true, size: 32.r),
                  errorWidget: (context, url, error) => Container(
                    height: 32.r,
                    width: 32.r,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Style.greyColor),
                    alignment: Alignment.center,
                    child: const Icon(FlutterRemix.image_line, color: Style.black),
                  ),
                ),
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.address?.address ?? "",
                    style: Style.interSemi(size: 13.sp, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  2.verticalSpace,
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Text(
                          order.user == null
                              ? AppHelpers.getTranslation(TrKeys.deletedUser)
                              : order.user?.firstname ?? "",
                          style: Style.interNormal(size: 13.sp, letterSpacing: -0.3),
                        ),
                        const VerticalDivider(),
                        Text(
                          order.user?.phone ?? "",
                          style: Style.interNormal(size: 13.sp, letterSpacing: -0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

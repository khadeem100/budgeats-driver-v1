import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:driver/application/providers.dart';
import 'package:driver/application/free_lunch/free_lunch_provider.dart';
import 'package:driver/infrastructure/models/data/free_lunch_data.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/styles/style.dart';

class BarCodeScreen extends ConsumerWidget {
  final FreeLunchOffer offer;

  const BarCodeScreen({super.key, required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freeLunchState = ref.watch(freeLunchProvider);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
      ),
      child: Column(
        children: [
          RestaurantItem(
            shopName: offer.restaurantName ?? 'Restaurant',
            shopImage: offer.restaurantImage ?? '',
            shopText: offer.mealName ?? '',
            shopUid: offer.id.toString(),
            shopId: offer.id.toString(),
          ),
          16.verticalSpace,
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Style.shimmerBase),
            ),
            padding: EdgeInsets.all(12.r),
            child: Row(
              children: [
                const Icon(
                  FlutterRemix.error_warning_fill,
                  color: Style.blueColor,
                ),
                12.horizontalSpace,
                Expanded(
                  child: Text(
                    'Show this code to the restaurant to redeem your free lunch',
                    style: Style.interRegular(size: 14.sp, letterSpacing: -0.3),
                  ),
                ),
              ],
            ),
          ),
          24.verticalSpace,
          // Show actual redemption code instead of static QR
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
            decoration: BoxDecoration(
              color: Style.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Style.shimmerBase, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  FlutterRemix.coupon_3_fill,
                  size: 48.r,
                  color: Style.orangeColor,
                ),
                16.verticalSpace,
                Text(
                  'Redemption Code',
                  style: Style.interRegular(size: 14.sp, color: Style.black),
                ),
                8.verticalSpace,
                Text(
                  offer.redemptionCode ?? '---',
                  style: Style.interSemi(
                    size: 32.sp,
                    color: Style.orangeColor,
                    letterSpacing: 4,
                  ),
                ),
                if (offer.description != null && offer.description!.isNotEmpty) ...[
                  12.verticalSpace,
                  Text(
                    offer.description!,
                    style: Style.interRegular(size: 12.sp, color: Style.black),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          24.verticalSpace,
          if (offer.redeemed != true)
            CustomButton(
              title: 'Redeem Free Lunch',
              isLoading: freeLunchState.isRedeeming,
              icon: Icon(
                FlutterRemix.check_double_fill,
                color: Style.black,
                size: 20.r,
              ),
              onPressed: () {
                ref.read(freeLunchProvider.notifier).redeemOffer(
                      context: context,
                      offerId: offer.id!,
                    );
                Navigator.pop(context);
              },
            ),
          if (offer.redeemed != true) 16.verticalSpace,
          if (offer.latitude != null && offer.longitude != null)
            CustomButton(
              title: AppHelpers.getTranslation(TrKeys.showOnMap),
              icon: const Icon(
                FlutterRemix.map_pin_range_fill,
                color: Style.black,
              ),
              onPressed: () async {
                Navigator.pop(context);
                final Uint8List markerMarketIcon =
                    await AppHelpers.getBytesFromAsset(
                        AppAssets.pngMarket, 100);
                ref.read(homeProvider.notifier).getRoutingAll(
                      // ignore: use_build_context_synchronously
                      context: context,
                      start: LatLng(
                        LocalStorage.getAddressSelected()?.latitude ??
                            AppConstants.demoLatitude,
                        LocalStorage.getAddressSelected()?.longitude ??
                            AppConstants.demoLongitude,
                      ),
                      end: LatLng(
                        offer.latitude!,
                        offer.longitude!,
                      ),
                      market: Marker(
                        markerId: const MarkerId("Shop"),
                        position: LatLng(
                          offer.latitude!,
                          offer.longitude!,
                        ),
                        icon: BitmapDescriptor.fromBytes(markerMarketIcon),
                      ),
                    );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:driver/application/free_lunch/free_lunch_provider.dart';
import 'package:driver/infrastructure/models/data/free_lunch_data.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/styles/style.dart';
import 'bar_code_screen.dart';

class FreeLunchScreen extends ConsumerStatefulWidget {
  const FreeLunchScreen({super.key});

  @override
  ConsumerState<FreeLunchScreen> createState() => _FreeLunchScreenState();
}

class _FreeLunchScreenState extends ConsumerState<FreeLunchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(freeLunchProvider.notifier).fetchFreeLunches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(freeLunchProvider);

    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Style.shimmerBase),
            ),
            padding: EdgeInsets.all(10.r),
            child: Row(
              children: [
                SizedBox(
                  height: 56.h,
                  child: Stack(
                    children: [
                      Container(
                        width: 48.r,
                        height: 48.r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Style.orangeColor,
                        ),
                        child: Center(
                          child: Icon(
                            FlutterRemix.restaurant_2_fill,
                            color: Style.white,
                            size: 24.r,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: AppHelpers.getTranslation(TrKeys.freeLunches),
                          style:
                              Style.interSemi(size: 14.sp, letterSpacing: -0.3),
                          children: [
                            TextSpan(
                              text: AppHelpers.getTranslation(
                                  TrKeys.matchingYourRank),
                              style: Style.interRegular(
                                  size: 14.sp, letterSpacing: -0.3),
                            )
                          ],
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          text: AppHelpers.getTranslation(TrKeys.onlyOne),
                          style:
                              Style.interSemi(size: 14.sp, letterSpacing: -0.3),
                          children: [
                            TextSpan(
                              text: AppHelpers.getTranslation(TrKeys.lunchCan),
                              style: Style.interRegular(
                                  size: 14.sp, letterSpacing: -0.3),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (state.isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.r,
                  color: Style.orangeColor,
                ),
              ),
            )
          else if (state.offers.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 48.h),
                  child: Text(
                    'No free lunches available',
                    style: Style.interRegular(
                      size: 16.sp,
                      color: Style.black,
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: MediaQuery.sizeOf(context).height / 2,
              child: ListView.builder(
                padding: EdgeInsets.only(top: 32.h),
                itemCount: state.offers.length,
                itemBuilder: (context, index) {
                  final FreeLunchOffer offer = state.offers[index];
                  return GestureDetector(
                    onTap: () {
                      if (offer.redeemed == true) return;
                      Navigator.pop(context);
                      AppHelpers.showCustomModalBottomSheet(
                        paddingTop: MediaQuery.paddingOf(context).top,
                        context: context,
                        modal: BarCodeScreen(offer: offer),
                        isDarkMode: false,
                      );
                    },
                    child: Stack(
                      children: [
                        RestaurantItem(
                          shopName: offer.restaurantName ?? 'Restaurant',
                          shopImage: offer.restaurantImage ?? '',
                          shopText: offer.mealName ?? '',
                          shopUid: offer.id.toString(),
                          shopId: offer.id.toString(),
                        ),
                        if (offer.redeemed == true)
                          Positioned(
                            top: 8.h,
                            right: 8.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'Redeemed',
                                style: Style.interSemi(
                                  size: 10.sp,
                                  color: Style.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

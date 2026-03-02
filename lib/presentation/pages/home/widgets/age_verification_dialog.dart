import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../infrastructure/services/services.dart';
import '../../../component/components.dart';
import '../../../styles/style.dart';

class AgeVerificationDialog extends StatelessWidget {
  final VoidCallback onVerified;
  final VoidCallback onNotVerified;

  const AgeVerificationDialog({
    super.key,
    required this.onVerified,
    required this.onNotVerified,
  });

  @override
  Widget build(BuildContext context) {
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
            Icons.verified_user_outlined,
            color: Style.redColor,
            size: 40.r,
          ),
          16.verticalSpace,
          Text(
            AppHelpers.getTranslation(TrKeys.ageVerificationRequired),
            style: Style.interBold(size: 18.sp, color: Style.redColor),
            textAlign: TextAlign.center,
          ),
          12.verticalSpace,
          Text(
            AppHelpers.getTranslation(TrKeys.ageVerificationMessage),
            style: Style.interNormal(size: 14.sp),
            textAlign: TextAlign.center,
          ),
          28.verticalSpace,
          CustomButton(
            title: AppHelpers.getTranslation(TrKeys.customerIdVerified),
            background: Style.greenColor,
            textColor: Style.white,
            onPressed: () {
              Navigator.pop(context);
              onVerified();
            },
          ),
          10.verticalSpace,
          CustomButton(
            title: AppHelpers.getTranslation(TrKeys.customerIdNotVerified),
            background: Style.redColor,
            textColor: Style.white,
            onPressed: () {
              Navigator.pop(context);
              onNotVerified();
            },
          ),
        ],
      ),
    );
  }
}

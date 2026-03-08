import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../infrastructure/models/models.dart';
import '../../../styles/style.dart';

class BudgeatsDriverIdCard extends StatefulWidget {
  final UserData? user;

  const BudgeatsDriverIdCard({Key? key, required this.user}) : super(key: key);

  @override
  State<BudgeatsDriverIdCard> createState() => _BudgeatsDriverIdCardState();
}

class _BudgeatsDriverIdCardState extends State<BudgeatsDriverIdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.value >= 0.5) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi;
          final isFront = angle <= math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront
                ? _CardFace(
                    title: 'Budgeats Driver ID',
                    child: _buildFront(user),
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardFace(
                      title: 'Account Manager',
                      child: _buildBack(user),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront(UserData? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.employeeNumber?.isNotEmpty == true
                        ? user!.employeeNumber!
                        : 'BGD-PENDING',
                    style: Style.interSemi(
                      size: 22.sp,
                      color: Style.white,
                      letterSpacing: 1,
                    ),
                  ),
                  8.verticalSpace,
                  Text(
                    '${user?.firstname ?? ''} ${user?.lastname ?? ''}'.trim(),
                    style: Style.interSemi(size: 18.sp, color: Style.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  6.verticalSpace,
                  Text(
                    user?.phone ?? 'No phone number',
                    style: Style.interRegular(
                      size: 13.sp,
                      color: Style.white.withOpacity(0.88),
                    ),
                  ),
                  4.verticalSpace,
                  Text(
                    (user?.role ?? 'driver').toUpperCase(),
                    style: Style.interSemi(
                      size: 12.sp,
                      color: const Color(0xFFFFD166),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 74.r,
              width: 74.r,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: user?.img?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: user!.img!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Icon(
                          FlutterRemix.user_3_fill,
                          color: Style.white,
                          size: 28.r,
                        ),
                      )
                    : Icon(
                        FlutterRemix.user_3_fill,
                        color: Style.white,
                        size: 28.r,
                      ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            _InfoChip(
              label: 'Email',
              value: user?.email?.isNotEmpty == true ? user!.email! : 'Not set',
            ),
            _InfoChip(
              label: 'Balance',
              value: user?.wallet?.price?.toStringAsFixed(2) ?? '0.00',
            ),
          ],
        ),
        16.verticalSpace,
        Text(
          'Tap to flip',
          style: Style.interRegular(
            size: 12.sp,
            color: Style.white.withOpacity(0.74),
          ),
        ),
      ],
    );
  }

  Widget _buildBack(UserData? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user?.accountManagerName?.isNotEmpty == true
              ? user!.accountManagerName!
              : 'Kelvin Okyere',
          style: Style.interSemi(size: 22.sp, color: Style.white),
        ),
        6.verticalSpace,
        Text(
          'Dedicated account manager',
          style: Style.interRegular(
            size: 13.sp,
            color: Style.white.withOpacity(0.84),
          ),
        ),
        24.verticalSpace,
        _ManagerRow(
          icon: Icons.badge_outlined,
          label: 'Employee No.',
          value: user?.employeeNumber?.isNotEmpty == true
              ? user!.employeeNumber!
              : 'BGD-PENDING',
        ),
        _ManagerRow(
          icon: FlutterRemix.phone_line,
          label: 'Phone',
          value: user?.accountManagerPhone?.isNotEmpty == true
              ? user!.accountManagerPhone!
              : 'Not assigned',
        ),
        _ManagerRow(
          icon: FlutterRemix.mail_line,
          label: 'Email',
          value: user?.accountManagerEmail?.isNotEmpty == true
              ? user!.accountManagerEmail!
              : 'Not assigned',
        ),
        const Spacer(),
        Text(
          'Budgeats support for verified drivers',
          style: Style.interRegular(
            size: 12.sp,
            color: Style.white.withOpacity(0.76),
          ),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardFace({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220.h,
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34.r,
                width: 34.r,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  FlutterRemix.bank_card_line,
                  color: Style.white,
                  size: 18.r,
                ),
              ),
              10.horizontalSpace,
              Text(
                title,
                style: Style.interSemi(size: 15.sp, color: Style.white),
              ),
            ],
          ),
          18.verticalSpace,
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Style.interRegular(
              size: 11.sp,
              color: Style.white.withOpacity(0.7),
            ),
          ),
          2.verticalSpace,
          SizedBox(
            width: 110.w,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Style.interSemi(size: 12.sp, color: Style.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ManagerRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        children: [
          Icon(icon, color: Style.white, size: 18.r),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Style.interRegular(
                    size: 11.sp,
                    color: Style.white.withOpacity(0.72),
                  ),
                ),
                2.verticalSpace,
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Style.interSemi(size: 13.sp, color: Style.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: unused_result

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:driver/infrastructure/models/models.dart';
import 'package:driver/presentation/component/components.dart';

import 'package:driver/application/providers.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/styles/style.dart';
import 'register_page.dart';
import 'reset/set_password_page.dart';

class RegisterConfirmationPage extends ConsumerStatefulWidget {
  final UserData userModel;
  final bool isResetPassword;
  final String verificationId;

  const RegisterConfirmationPage({
    super.key,
    required this.userModel,
    this.isResetPassword = false,
    required this.verificationId,
  });

  @override
  ConsumerState<RegisterConfirmationPage> createState() =>
      _RegisterConfirmationPageState();
}

class _RegisterConfirmationPageState
    extends ConsumerState<RegisterConfirmationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(registerConfirmationProvider);
      ref.read(registerConfirmationProvider.notifier).startTimer();
    });
  }

  @override
  void deactivate() {
    ref.read(registerConfirmationProvider.notifier).disposeTimer();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(registerConfirmationProvider.notifier);
    final state = ref.watch(registerConfirmationProvider);
    final bool isDarkMode = LocalStorage.getAppThemeMode();
    final bool isLtr = LocalStorage.getLangLtr();
    ref.listen(registerConfirmationProvider, (previous, next) {
      if (previous!.isSuccess != next.isSuccess && next.isSuccess) {
        Navigator.pop(context);
        AppHelpers.showCustomModalBottomSheetWithoutIosIcon(
          context: context,
          modal: const RegisterPage(
            isOnlyEmail: false,
          ),
          isDarkMode: isDarkMode,
        );
      }
      if (previous.isResetPasswordSuccess != next.isResetPasswordSuccess &&
          next.isResetPasswordSuccess) {
        Navigator.pop(context);
        AppHelpers.showCustomModalBottomSheetWithoutIosIcon(
          context: context,
          modal: const SetPasswordPage(),
          isDarkMode: isDarkMode,
        );
      }
    });
    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: AbsorbPointer(
        absorbing: state.isLoading || state.isResending,
        child: KeyboardDisable(
          child: Container(
            padding: MediaQuery.viewInsetsOf(context),
            decoration: BoxDecoration(
                color: Style.greyColor.withOpacity(0.96),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                )),
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        AppBarBottomSheet(
                          title: AppHelpers.getTranslation(TrKeys.enterOtp),
                        ),
                        Text(
                          AppHelpers.getTranslation(TrKeys.sendOtp),
                          style: Style.interRegular(
                            size: 14,
                            color: Style.black,
                          ),
                        ),
                        Text(
                          widget.userModel.email ?? "",
                          style: Style.interRegular(
                            size: 14,
                            color: Style.black,
                          ),
                        ),
                        40.verticalSpace,
                        _OtpInput(
                          codeLength: 6,
                          currentCode: state.confirmCode,
                          onCodeChanged: notifier.setCode,
                          isDarkMode: isDarkMode,
                          isError: state.isCodeError,
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.paddingOf(context).bottom,
                          top: 120.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomButton(
                            isLoading: state.isResending,
                            title: state.isTimeExpired
                                ? AppHelpers.getTranslation(TrKeys.resendOtp)
                                : state.timerText,
                            onPressed: () {
                              if (state.isTimeExpired) {
                                widget.verificationId.isEmpty
                                    ? notifier.resendConfirmation(
                                        context, widget.userModel.email ?? "",
                                        isResetPassword: widget.isResetPassword)
                                    : notifier.sendCodeToNumber(
                                        context,
                                        widget.userModel.email ?? "",
                                      );
                                notifier.startTimer();
                              }
                            },
                            weight: (MediaQuery.sizeOf(context).width - 40) / 3,
                            background: Style.black,
                            textColor: Style.white,
                          ),
                          CustomButton(
                            isLoading: state.isLoading,
                            title: AppHelpers.getTranslation(TrKeys.confirmation),
                            onPressed: () {
                              if (state.confirmCode.length == 6) {
                                if (widget.isResetPassword) {
                                  widget.verificationId.isEmpty
                                      ? notifier.confirmCodeResetPassword(
                                          context, widget.userModel.email ?? "")
                                      : notifier
                                          .confirmCodeResetPasswordWithPhone(
                                              context,
                                              widget.userModel.email ?? "",
                                              widget.verificationId);
                                } else {
                                  widget.verificationId.isEmpty
                                      ? notifier.confirmCode(context)
                                      : notifier.confirmCodeWithFirebase(
                                          context: context,
                                          verificationId:
                                              widget.verificationId);
                                }
                              }
                            },
                            weight:
                                2 * (MediaQuery.sizeOf(context).width - 40) / 3,
                            background: state.isConfirm
                                ? Style.primaryColor
                                : Style.white,
                            textColor:
                                state.isConfirm ? Style.black : Style.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pure-Flutter OTP input that replaces the removed sms_autofill dependency.
class _OtpInput extends StatefulWidget {
  final int codeLength;
  final String currentCode;
  final ValueChanged<String> onCodeChanged;
  final bool isDarkMode;
  final bool isError;

  const _OtpInput({
    required this.codeLength,
    required this.currentCode,
    required this.onCodeChanged,
    required this.isDarkMode,
    this.isError = false,
  });

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(widget.codeLength, (_) => FocusNode());

    // Pre-fill if there's already a code
    for (int i = 0; i < widget.currentCode.length && i < widget.codeLength; i++) {
      _controllers[i].text = widget.currentCode[i];
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _collectCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste — distribute characters across fields
      final chars = value.split('');
      for (int i = 0; i < chars.length && (index + i) < widget.codeLength; i++) {
        _controllers[index + i].text = chars[i];
      }
      final nextIndex = (index + chars.length).clamp(0, widget.codeLength - 1);
      _focusNodes[nextIndex].requestFocus();
    } else if (value.isNotEmpty) {
      // Move to next field
      if (index < widget.codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    }
    widget.onCodeChanged(_collectCode());
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      widget.onCodeChanged(_collectCode());
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isError
        ? Style.redColor
        : widget.isDarkMode
            ? Style.borderColor
            : Style.black;
    final bgColor = widget.isDarkMode ? Style.black : Style.transparent;
    final textColor = widget.isDarkMode ? Style.white : Style.black;

    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.codeLength, (i) {
          return Container(
            width: 44.r,
            height: 56.r,
            margin: EdgeInsets.symmetric(horizontal: 5.r),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: KeyboardListener(
              focusNode: FocusNode(), // wrapper node for key events
              onKeyEvent: (event) => _onKeyEvent(i, event),
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 2, // allow 2 so paste detection works
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Style.interNormal(size: 15.sp, color: textColor),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => _onChanged(i, val),
              ),
            ),
          );
        }),
      ),
    );
  }
}

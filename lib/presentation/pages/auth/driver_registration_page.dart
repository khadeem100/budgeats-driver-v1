import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:driver/application/providers.dart';
import 'package:driver/infrastructure/models/models.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/styles/style.dart';

class DriverRegistrationPage extends ConsumerStatefulWidget {
  final UserData userModel;

  const DriverRegistrationPage({
    super.key,
    required this.userModel,
  });

  @override
  ConsumerState<DriverRegistrationPage> createState() =>
      _DriverRegistrationPageState();
}

class _DriverRegistrationPageState
    extends ConsumerState<DriverRegistrationPage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _password;
  late final TextEditingController _confirmPassword;
  late final TextEditingController _brand;
  late final TextEditingController _vehicleModel;
  late final TextEditingController _number;
  late final TextEditingController _color;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _length;
  late final TextEditingController _width;

  String? _vehicleType;
  String? _imagePath;

  List<String> get _items => [
        AppHelpers.getTranslation(TrKeys.benzine),
        AppHelpers.getTranslation(TrKeys.diesel),
        AppHelpers.getTranslation(TrKeys.gas),
        AppHelpers.getTranslation(TrKeys.motorbike),
        AppHelpers.getTranslation(TrKeys.bike),
        AppHelpers.getTranslation(TrKeys.foot),
      ];

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.userModel.firstname ?? '');
    _lastName = TextEditingController(text: widget.userModel.lastname ?? '');
    _password = TextEditingController(text: widget.userModel.password ?? '');
    _confirmPassword =
        TextEditingController(text: widget.userModel.conPassword ?? '');
    _brand = TextEditingController();
    _vehicleModel = TextEditingController();
    _number = TextEditingController();
    _color = TextEditingController();
    _height = TextEditingController();
    _weight = TextEditingController();
    _length = TextEditingController();
    _width = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(signUpProvider.notifier).setEmail(widget.userModel.email ?? '');
      ref.read(profileImageProvider.notifier).setUrlCar(null);
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _brand.dispose();
    _vehicleModel.dispose();
    _number.dispose();
    _color.dispose();
    _height.dispose();
    _weight.dispose();
    _length.dispose();
    _width.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      return;
    }

    setState(() {
      _imagePath = pickedFile.path;
    });

    if (!mounted) {
      return;
    }

    ref.read(profileImageProvider.notifier).setUrlCar(null);
    await ref.read(profileImageProvider.notifier).editCarImage(
          context: context,
          path: pickedFile.path,
        );
  }

  Future<void> _submit() async {
    final notifier = ref.read(signUpProvider.notifier);
    final imageState = ref.read(profileImageProvider);

    final success = await notifier.registerDriver(
      context: context,
      email: widget.userModel.email ?? '',
      firstname: _firstName.text,
      lastname: _lastName.text,
      phone: widget.userModel.phone,
      password: _password.text,
      confirmPassword: _confirmPassword.text,
      typeOfTechnique: AppHelpers.getTranslationReverse(_vehicleType ?? ''),
      brand: _brand.text,
      model: _vehicleModel.text,
      number: _number.text,
      color: _color.text,
      height: _height.text,
      weight: _weight.text,
      length: _length.text,
      width: _width.text,
      imageUrl: imageState.carImageUrl,
    );

    if (!success || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registration submitted'),
        content: const Text(
          'Your driver account has been created and is waiting for admin approval.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signUpState = ref.watch(signUpProvider);
    final imageState = ref.watch(profileImageProvider);
    final isDarkMode = LocalStorage.getAppThemeMode();
    final isLtr = LocalStorage.getLangLtr();

    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: KeyboardDisable(
        child: Container(
          margin: MediaQuery.viewInsetsOf(context),
          decoration: BoxDecoration(
            color: Style.greyColor.withValues(alpha: 0.96),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
            ),
          ),
          width: double.infinity,
          child: Padding(
            padding: REdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBarBottomSheet(
                    title: AppHelpers.getTranslation(TrKeys.becomeDriver),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.userModel.email ?? '',
                      style: Style.interRegular(size: 14, color: Style.black),
                    ),
                  ),
                  24.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.firstname)
                              .toUpperCase(),
                          textController: _firstName,
                          onChanged: ref.read(signUpProvider.notifier).setFirstName,
                          isError: signUpState.isFirstNameInvalid,
                          descriptionText: signUpState.isFirstNameInvalid
                              ? AppHelpers.getTranslation(TrKeys.cannotBeEmpty)
                              : null,
                        ),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: OutlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.surname)
                              .toUpperCase(),
                          textController: _lastName,
                          onChanged: ref.read(signUpProvider.notifier).setLatName,
                        ),
                      ),
                    ],
                  ),
                  24.verticalSpace,
                  OutlinedBorderTextField(
                    label: AppHelpers.getTranslation(TrKeys.password)
                        .toUpperCase(),
                    textController: _password,
                    obscure: signUpState.showPassword,
                    suffixIcon: IconButton(
                      splashRadius: 25,
                      icon: Icon(
                        signUpState.showPassword
                            ? FlutterRemix.eye_line
                            : FlutterRemix.eye_close_line,
                        color: isDarkMode ? Style.black : Style.hintColor,
                        size: 20.r,
                      ),
                      onPressed: () =>
                          ref.read(signUpProvider.notifier).toggleShowPassword(),
                    ),
                    onChanged: ref.read(signUpProvider.notifier).setPassword,
                    isError: signUpState.isPasswordInvalid,
                    descriptionText: signUpState.isPasswordInvalid
                        ? AppHelpers.getTranslation(
                            TrKeys.passwordShouldContainMinimum6Characters,
                          )
                        : null,
                  ),
                  24.verticalSpace,
                  OutlinedBorderTextField(
                    label: AppHelpers.getTranslation(TrKeys.confirmPassword)
                        .toUpperCase(),
                    textController: _confirmPassword,
                    obscure: signUpState.showConfirmPassword,
                    suffixIcon: IconButton(
                      splashRadius: 25,
                      icon: Icon(
                        signUpState.showConfirmPassword
                            ? FlutterRemix.eye_line
                            : FlutterRemix.eye_close_line,
                        color: isDarkMode ? Style.black : Style.hintColor,
                        size: 20.r,
                      ),
                      onPressed: () => ref
                          .read(signUpProvider.notifier)
                          .toggleShowConfirmPassword(),
                    ),
                    onChanged:
                        ref.read(signUpProvider.notifier).setConfirmPassword,
                    isError: signUpState.isConfirmPasswordInvalid,
                    descriptionText: signUpState.isConfirmPasswordInvalid
                        ? AppHelpers.getTranslation(
                            TrKeys.confirmPasswordIsNotTheSame,
                          )
                        : null,
                  ),
                  24.verticalSpace,
                  DropdownButtonFormField<String>(
                    initialValue: _vehicleType,
                    items: _items
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _vehicleType = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: AppHelpers.getTranslation(TrKeys.typeTechnique)
                          .toUpperCase(),
                      labelStyle: Style.interNormal(
                        size: 14.sp,
                        color: Style.black,
                      ),
                      contentPadding:
                          REdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Style.shimmerBase),
                      ),
                      border: const UnderlineInputBorder(),
                      focusedBorder: const UnderlineInputBorder(),
                    ),
                  ),
                  24.verticalSpace,
                  UnderlinedBorderTextField(
                    label: AppHelpers.getTranslation(TrKeys.carBrand),
                    textController: _brand,
                  ),
                  24.verticalSpace,
                  UnderlinedBorderTextField(
                    label: AppHelpers.getTranslation(TrKeys.carModels),
                    textController: _vehicleModel,
                  ),
                  24.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: UnderlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.stateNumber),
                          textController: _number,
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: UnderlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.color),
                          textController: _color,
                        ),
                      ),
                    ],
                  ),
                  24.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: UnderlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.height),
                          textController: _height,
                          inputType: TextInputType.number,
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: UnderlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.weight),
                          textController: _weight,
                          inputType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  24.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: UnderlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.length),
                          textController: _length,
                          inputType: TextInputType.number,
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: UnderlinedBorderTextField(
                          label: AppHelpers.getTranslation(TrKeys.width),
                          textController: _width,
                          inputType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  24.verticalSpace,
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      height: 160.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Style.hintColor),
                      ),
                      child: imageState.carImageUrl == null
                          ? _imagePath == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      FlutterRemix.upload_cloud_2_line,
                                      size: 36.sp,
                                      color: Style.primaryColor,
                                    ),
                                    16.verticalSpace,
                                    Text(
                                      AppHelpers.getTranslation(
                                          TrKeys.carPicture),
                                      style: Style.interSemi(size: 14.sp),
                                    ),
                                    Text(
                                      AppHelpers.getTranslation(
                                          TrKeys.recommendedSize),
                                      style: Style.interRegular(size: 14.sp),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(20.r),
                                  child: Image.file(
                                    File(_imagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                          : CommonImage(
                              imageUrl: imageState.carImageUrl,
                              height: 160,
                              radius: 20,
                            ),
                    ),
                  ),
                  30.verticalSpace,
                  CustomButton(
                    isLoading: signUpState.isLoading,
                    title: AppHelpers.getTranslation(TrKeys.register),
                    onPressed: _submit,
                  ),
                  24.verticalSpace,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
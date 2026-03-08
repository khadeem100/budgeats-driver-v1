import '../handlers/handlers.dart';
import '../../infrastructure/models/models.dart';

abstract class AuthRepository {
  Future<ApiResult<LoginResponse>> login({
    required String email,
    required String password,
  });

  Future<ApiResult<LoginResponse>> loginWithSocial({
    String? email,
    String? displayName,
    String? id,
  });

  Future<ApiResult> signUp({
    required String email,
  });

  Future<ApiResult<VerifyData>> sigUpWithPhone({
    required UserData user,
  });

  Future<ApiResult<RegisterResponse>> sendOtp({required String phone});

  Future<ApiResult<RegisterResponse>> forgotPassword({required String email});

  Future<ApiResult<VerifyData>> forgotPasswordConfirm({
    required String verifyCode,
    required String email,
  });

  Future<ApiResult<VerifyData>> forgotPasswordConfirmWithPhone({
    required String phone,
  });

  Future<ApiResult<VerifyPhoneResponse>> verifyPhone({
    required String verifyId,
    required String verifyCode,
  });

  Future<ApiResult<VerifyPhoneResponse>> verifyEmail({
    required String verifyCode,
  });

  Future<ApiResult<VerifyData>> sigUpWithData({
    required UserData user,
  });

  Future<ApiResult<void>> signUpDriver({
    required String email,
    required String firstname,
    String? lastname,
    String? phone,
    required String password,
    String? referral,
    required String typeOfTechnique,
    required String brand,
    required String model,
    required String number,
    required String color,
    required String height,
    required String weight,
    required String length,
    required String width,
    String? imageUrl,
  });

  Future<ApiResult<bool>>  checkPhone({required String phone});

}

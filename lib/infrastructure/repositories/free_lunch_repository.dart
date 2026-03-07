import 'package:flutter/material.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/domain/interface/free_lunch.dart';
import 'package:driver/infrastructure/models/data/free_lunch_data.dart';
import 'package:driver/infrastructure/services/services.dart';
import '../../../domain/handlers/handlers.dart';

class FreeLunchRepository implements FreeLunchRepositoryFacade {
  @override
  Future<ApiResult<FreeLunchResponse>> getFreeLunches() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/deliveryman/free-lunches',
        queryParameters: {
          'lang': LocalStorage.getLanguage()?.locale ?? 'en',
        },
      );
      return ApiResult.success(
        data: FreeLunchResponse.fromJson(response.data),
      );
    } catch (e) {
      debugPrint('==> get free lunches failure: $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  @override
  Future<ApiResult<dynamic>> redeemFreeLunch(int offerId) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/deliveryman/free-lunches/$offerId/redeem',
      );
      return const ApiResult.success(data: null);
    } catch (e) {
      debugPrint('==> redeem free lunch failure: $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }
}

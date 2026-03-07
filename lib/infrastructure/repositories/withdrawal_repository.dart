import 'package:flutter/material.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/services/services.dart';
import '../../../domain/handlers/handlers.dart';

class WithdrawalRepository {
  Future<ApiResult<Map<String, dynamic>>> getBalance() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/deliveryman/withdrawals/balance',
      );
      return ApiResult.success(
        data: Map<String, dynamic>.from(response.data['data'] ?? {}),
      );
    } catch (e) {
      debugPrint('==> get withdrawal balance failure: $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  Future<ApiResult<Map<String, dynamic>>> requestWithdrawal({double? amount}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/deliveryman/withdrawals',
        data: {
          if (amount != null) 'amount': amount,
        },
      );
      return ApiResult.success(
        data: Map<String, dynamic>.from(response.data['data'] ?? {}),
      );
    } catch (e) {
      debugPrint('==> request withdrawal failure: $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  Future<ApiResult<List<dynamic>>> getWithdrawalHistory({int page = 1}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/deliveryman/withdrawals',
        queryParameters: {'page': page, 'perPage': 20},
      );
      final data = response.data['data'] ?? [];
      return ApiResult.success(data: List<dynamic>.from(data));
    } catch (e) {
      debugPrint('==> get withdrawal history failure: $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }
}

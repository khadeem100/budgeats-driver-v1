import 'package:flutter/material.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/domain/handlers/handlers.dart';
import 'package:driver/domain/interface/driver_chat_repository.dart';
import 'package:driver/infrastructure/models/models.dart';
import 'package:driver/infrastructure/services/services.dart';

class DriverChatRepositoryImpl implements DriverChatRepositoryFacade {
  @override
  Future<ApiResult<DriverChatOverviewResponse>> getOverview({int perPage = 100}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/deliveryman/chat/overview',
        queryParameters: {'perPage': perPage},
      );
      return ApiResult.success(
        data: DriverChatOverviewResponse.fromJson(response.data),
      );
    } catch (e) {
      debugPrint('===> get driver chat overview error $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  @override
  Future<ApiResult<DriverChatMessageData>> sendMessage({
    required String message,
    String messageType = 'general',
    int? orderId,
  }) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/deliveryman/chat/messages',
        data: {
          'message': message,
          'message_type': messageType,
          if (orderId != null) 'order_id': orderId,
        },
      );
      return ApiResult.success(
        data: DriverChatMessageData.fromJson(response.data['data']['message']),
      );
    } catch (e) {
      debugPrint('===> send driver chat message error $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  @override
  Future<ApiResult<void>> reportMessage({required int messageId, String? reason}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/deliveryman/chat/reports',
        data: {
          'message_id': messageId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
      return const ApiResult.success(data: null);
    } catch (e) {
      debugPrint('===> report driver chat message error $e');
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }
}

import '../handlers/handlers.dart';
import '../../infrastructure/models/models.dart';

abstract class DriverChatRepositoryFacade {
  Future<ApiResult<DriverChatOverviewResponse>> getOverview({int perPage = 100});

  Future<ApiResult<DriverChatMessageData>> sendMessage({
    required String message,
    String messageType = 'general',
    int? orderId,
  });

  Future<ApiResult<void>> reportMessage({
    required int messageId,
    String? reason,
  });
}

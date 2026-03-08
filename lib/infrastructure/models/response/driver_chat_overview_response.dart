import '../data/driver_chat_message.dart';

class DriverChatOverviewResponse {
  DriverChatOverviewResponse({
    this.timestamp,
    this.status,
    this.message,
    this.data,
  });

  String? timestamp;
  bool? status;
  String? message;
  DriverChatOverviewData? data;

  DriverChatOverviewResponse.fromJson(Map<String, dynamic> json) {
    timestamp = json['timestamp'];
    status = json['status'];
    message = json['message'];
    data = json['data'] != null
        ? DriverChatOverviewData.fromJson(json['data'])
        : null;
  }
}

class DriverChatOverviewData {
  DriverChatOverviewData({
    this.messages,
    this.chatStatus,
  });

  List<DriverChatMessageData>? messages;
  DriverChatStatusData? chatStatus;

  DriverChatOverviewData.fromJson(Map<String, dynamic> json) {
    if (json['messages'] != null) {
      messages = (json['messages'] as List<dynamic>)
          .map((item) => DriverChatMessageData.fromJson(item))
          .toList();
    } else {
      messages = [];
    }

    chatStatus = json['chat_status'] != null
        ? DriverChatStatusData.fromJson(json['chat_status'])
        : null;
  }
}

class DriverChatStatusData {
  DriverChatStatusData({
    this.isBanned,
    this.chatBannedUntil,
    this.chatBanReason,
    this.chatBanCount,
    this.messageTypes,
  });

  bool? isBanned;
  String? chatBannedUntil;
  String? chatBanReason;
  int? chatBanCount;
  List<String>? messageTypes;

  DriverChatStatusData.fromJson(Map<String, dynamic> json) {
    isBanned = json['is_banned'] == true;
    chatBannedUntil = json['chat_banned_until'];
    chatBanReason = json['chat_ban_reason'];
    chatBanCount = json['chat_ban_count'];
    if (json['message_types'] != null) {
      messageTypes = List<String>.from(json['message_types']);
    } else {
      messageTypes = [];
    }
  }
}

class WalletHistoryData {
  WalletHistoryData({
    this.id,
    this.uuid,
    this.walletUuid,
    this.transactionId,
    this.type,
    this.price,
    this.note,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  WalletHistoryData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    uuid = json['uuid'];
    walletUuid = json['wallet_uuid'];
    transactionId = json['transaction_id'];
    type = json['type'];
    price = (json['price'] as num?)?.toDouble();
    note = json['note'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  int? id;
  String? uuid;
  String? walletUuid;
  int? transactionId;
  String? type;
  double? price;
  String? note;
  String? status;
  String? createdAt;
  String? updatedAt;
}

class DriverChatMessageData {
  DriverChatMessageData({
    this.id,
    this.message,
    this.messageType,
    this.moderationStatus,
    this.hidden,
    this.reportedCount,
    this.createdAt,
    this.sender,
    this.order,
  });

  int? id;
  String? message;
  String? messageType;
  String? moderationStatus;
  bool? hidden;
  int? reportedCount;
  String? createdAt;
  DriverChatUserData? sender;
  DriverChatOrderData? order;

  DriverChatMessageData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    message = json['message'];
    messageType = json['message_type'];
    moderationStatus = json['moderation_status'];
    hidden = json['hidden'] == true;
    reportedCount = json['reported_count'];
    createdAt = json['created_at'];
    sender = json['sender'] != null
        ? DriverChatUserData.fromJson(json['sender'])
        : null;
    order = json['order'] != null
        ? DriverChatOrderData.fromJson(json['order'])
        : null;
  }
}

class DriverChatUserData {
  DriverChatUserData({
    this.id,
    this.firstname,
    this.lastname,
    this.img,
    this.email,
    this.phone,
  });

  int? id;
  String? firstname;
  String? lastname;
  String? img;
  String? email;
  String? phone;

  String get fullName => '${firstname ?? ''} ${lastname ?? ''}'.trim();

  DriverChatUserData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    firstname = json['firstname'];
    lastname = json['lastname'];
    img = json['img'];
    email = json['email'];
    phone = json['phone'];
  }
}

class DriverChatOrderData {
  DriverChatOrderData({
    this.id,
    this.status,
    this.totalPrice,
    this.deliveryDate,
    this.deliveryTime,
    this.address,
    this.note,
    this.shop,
    this.customer,
    this.deliverymanId,
  });

  int? id;
  String? status;
  num? totalPrice;
  String? deliveryDate;
  String? deliveryTime;
  dynamic address;
  String? note;
  DriverChatShopData? shop;
  DriverChatCustomerData? customer;
  int? deliverymanId;

  DriverChatOrderData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    status = json['status'];
    totalPrice = json['total_price'];
    deliveryDate = json['delivery_date'];
    deliveryTime = json['delivery_time'];
    address = json['address'];
    note = json['note'];
    shop = json['shop'] != null ? DriverChatShopData.fromJson(json['shop']) : null;
    customer = json['customer'] != null
        ? DriverChatCustomerData.fromJson(json['customer'])
        : null;
    deliverymanId = json['deliveryman_id'];
  }

  String get addressText {
    if (address is String) {
      return address as String;
    }
    if (address is Map<String, dynamic>) {
      final map = address as Map<String, dynamic>;
      return [
        map['address'],
        map['house'],
        map['street_house_number'],
      ].where((item) => (item ?? '').toString().isNotEmpty).join(', ');
    }
    return '';
  }
}

class DriverChatShopData {
  DriverChatShopData({this.id, this.uuid, this.title});

  int? id;
  String? uuid;
  String? title;

  DriverChatShopData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    uuid = json['uuid'];
    title = json['title'];
  }
}

class DriverChatCustomerData {
  DriverChatCustomerData({this.id, this.firstname, this.lastname, this.phone});

  int? id;
  String? firstname;
  String? lastname;
  String? phone;

  String get fullName => '${firstname ?? ''} ${lastname ?? ''}'.trim();

  DriverChatCustomerData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    firstname = json['firstname'];
    lastname = json['lastname'];
    phone = json['phone'];
  }
}

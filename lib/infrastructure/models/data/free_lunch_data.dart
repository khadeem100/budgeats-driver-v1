class FreeLunchOffer {
  FreeLunchOffer({
    int? id,
    String? restaurantName,
    String? restaurantImage,
    String? mealName,
    String? description,
    String? redemptionCode,
    double? latitude,
    double? longitude,
    String? address,
    bool? active,
    String? validFrom,
    String? validUntil,
    bool? redeemed,
    String? redeemedAt,
  }) {
    _id = id;
    _restaurantName = restaurantName;
    _restaurantImage = restaurantImage;
    _mealName = mealName;
    _description = description;
    _redemptionCode = redemptionCode;
    _latitude = latitude;
    _longitude = longitude;
    _address = address;
    _active = active;
    _validFrom = validFrom;
    _validUntil = validUntil;
    _redeemed = redeemed;
    _redeemedAt = redeemedAt;
  }

  FreeLunchOffer.fromJson(dynamic json) {
    _id = json['id'];
    _restaurantName = json['restaurant_name'];
    _restaurantImage = json['restaurant_image'];
    _mealName = json['meal_name'];
    _description = json['description'];
    _redemptionCode = json['redemption_code'];
    _latitude = double.tryParse(json['latitude']?.toString() ?? '');
    _longitude = double.tryParse(json['longitude']?.toString() ?? '');
    _address = json['address'];
    _active = json['active'] == 1 || json['active'] == true;
    _validFrom = json['valid_from'];
    _validUntil = json['valid_until'];

    // Check assignment pivot if present
    if (json['pivot'] != null) {
      _redeemed = json['pivot']['redeemed'] == 1 || json['pivot']['redeemed'] == true;
      _redeemedAt = json['pivot']['redeemed_at'];
    } else if (json['assignment'] != null) {
      _redeemed = json['assignment']['redeemed'] == 1 || json['assignment']['redeemed'] == true;
      _redeemedAt = json['assignment']['redeemed_at'];
    } else {
      _redeemed = json['redeemed'] == 1 || json['redeemed'] == true;
      _redeemedAt = json['redeemed_at'];
    }
  }

  int? _id;
  String? _restaurantName;
  String? _restaurantImage;
  String? _mealName;
  String? _description;
  String? _redemptionCode;
  double? _latitude;
  double? _longitude;
  String? _address;
  bool? _active;
  String? _validFrom;
  String? _validUntil;
  bool? _redeemed;
  String? _redeemedAt;

  int? get id => _id;
  String? get restaurantName => _restaurantName;
  String? get restaurantImage => _restaurantImage;
  String? get mealName => _mealName;
  String? get description => _description;
  String? get redemptionCode => _redemptionCode;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get address => _address;
  bool? get active => _active;
  String? get validFrom => _validFrom;
  String? get validUntil => _validUntil;
  bool? get redeemed => _redeemed;
  String? get redeemedAt => _redeemedAt;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['restaurant_name'] = _restaurantName;
    map['restaurant_image'] = _restaurantImage;
    map['meal_name'] = _mealName;
    map['description'] = _description;
    map['redemption_code'] = _redemptionCode;
    map['latitude'] = _latitude;
    map['longitude'] = _longitude;
    map['address'] = _address;
    map['active'] = _active;
    map['valid_from'] = _validFrom;
    map['valid_until'] = _validUntil;
    return map;
  }
}

class FreeLunchResponse {
  FreeLunchResponse({String? timestamp, bool? status, String? message, List<FreeLunchOffer>? data}) {
    _timestamp = timestamp;
    _status = status;
    _message = message;
    _data = data;
  }

  FreeLunchResponse.fromJson(dynamic json) {
    _timestamp = json['timestamp'];
    _status = json['status'];
    _message = json['message'];
    if (json['data'] != null) {
      _data = [];
      json['data'].forEach((v) {
        _data!.add(FreeLunchOffer.fromJson(v));
      });
    }
  }

  String? _timestamp;
  bool? _status;
  String? _message;
  List<FreeLunchOffer>? _data;

  String? get timestamp => _timestamp;
  bool? get status => _status;
  String? get message => _message;
  List<FreeLunchOffer>? get data => _data;
}

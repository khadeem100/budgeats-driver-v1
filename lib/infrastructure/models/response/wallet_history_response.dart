import '../data/wallet_history_data.dart';

class WalletHistoryResponse {
  WalletHistoryResponse({this.data = const []});

  List<WalletHistoryData> data = const [];

  WalletHistoryResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] == null
        ? []
        : List<WalletHistoryData>.from(
            json['data'].map((x) => WalletHistoryData.fromJson(x)),
          );
  }
}

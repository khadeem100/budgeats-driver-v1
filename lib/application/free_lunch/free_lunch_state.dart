import 'package:flutter/foundation.dart';
import 'package:driver/infrastructure/models/data/free_lunch_data.dart';

@immutable
class FreeLunchState {
  final bool isLoading;
  final bool isRedeeming;
  final List<FreeLunchOffer> offers;

  const FreeLunchState({
    this.isLoading = false,
    this.isRedeeming = false,
    this.offers = const [],
  });

  FreeLunchState copyWith({
    bool? isLoading,
    bool? isRedeeming,
    List<FreeLunchOffer>? offers,
  }) {
    return FreeLunchState(
      isLoading: isLoading ?? this.isLoading,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      offers: offers ?? this.offers,
    );
  }
}

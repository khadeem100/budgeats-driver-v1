import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'free_lunch_state.dart';

class FreeLunchNotifier extends StateNotifier<FreeLunchState> {
  FreeLunchNotifier() : super(const FreeLunchState());

  Future<void> fetchFreeLunches() async {
    state = state.copyWith(isLoading: true);
    final result = await freeLunchRepository.getFreeLunches();
    result.when(
      success: (data) {
        state = state.copyWith(
          isLoading: false,
          offers: data.data ?? [],
        );
      },
      failure: (error, statusCode) {
        state = state.copyWith(isLoading: false);
      },
    );
  }

  Future<void> redeemOffer({
    required BuildContext context,
    required int offerId,
  }) async {
    state = state.copyWith(isRedeeming: true);
    final result = await freeLunchRepository.redeemFreeLunch(offerId);
    result.when(
      success: (data) {
        state = state.copyWith(isRedeeming: false);
        AppHelpers.showCheckTopSnackBarInfo(
          context,
          'Free lunch redeemed successfully!',
        );
        // Refresh the list
        fetchFreeLunches();
      },
      failure: (error, statusCode) {
        state = state.copyWith(isRedeeming: false);
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.getTranslation(error),
        );
      },
    );
  }
}

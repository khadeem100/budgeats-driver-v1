import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'free_lunch_notifier.dart';
import 'free_lunch_state.dart';

final freeLunchProvider =
    StateNotifierProvider<FreeLunchNotifier, FreeLunchState>(
  (ref) => FreeLunchNotifier(),
);

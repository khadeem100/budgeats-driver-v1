import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finances_notifier.dart';
import 'finances_state.dart';

final financesProvider =
    StateNotifierProvider<FinancesNotifier, FinancesState>(
  (ref) => FinancesNotifier(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subscription_provider.dart';

final monthlyBudgetProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(subscriptionRepositoryProvider);
  final value = await repository.getSetting('monthly_budget', fallback: '0');
  final budget = double.tryParse(value);
  if (budget == null || !budget.isFinite || budget < 0) {
    throw FormatException('Invalid monthly budget: $value');
  }
  return budget;
});

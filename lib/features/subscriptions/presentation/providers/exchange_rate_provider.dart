import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/exchange_rate_service.dart';
import 'subscription_provider.dart';

final exchangeRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  final service = ExchangeRateService(
    ref.watch(subscriptionRepositoryProvider),
  );
  ref.onDispose(service.close);
  return service.loadRates(refresh: true);
});

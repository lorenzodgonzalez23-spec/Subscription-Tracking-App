import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/subscriptions/data/subscription_repository.dart';

class ExchangeRateService {
  ExchangeRateService(this.repository, {http.Client? client})
    : _client = client ?? http.Client();

  final SubscriptionRepository repository;
  final http.Client _client;

  Future<Map<String, double>> loadRates({bool refresh = false}) async {
    final cached = await repository.getExchangeRates();
    if (!refresh && cached.containsKey('PHP')) return cached;

    try {
      final response = await _client
          .get(Uri.parse('https://open.er-api.com/v6/latest/PHP'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception(
          'Exchange-rate service returned ${response.statusCode}',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['result'] != 'success' ||
          body['rates'] is! Map<String, dynamic>) {
        throw const FormatException('Exchange-rate response was invalid');
      }
      final rawRates = body['rates'] as Map<String, dynamic>;
      final rates = <String, double>{'PHP': 1};
      for (final entry in rawRates.entries) {
        final unitsPerPeso = (entry.value as num).toDouble();
        if (unitsPerPeso > 0) rates[entry.key] = 1 / unitsPerPeso;
      }
      await repository.saveExchangeRates(rates);
      return rates;
    } on http.ClientException {
      if (cached.containsKey('PHP')) return cached;
      rethrow;
    } on TimeoutException {
      if (cached.containsKey('PHP')) return cached;
      rethrow;
    }
  }

  double convertToPhp(
    double amount,
    String currency,
    Map<String, double> rates,
  ) {
    final rate = rates[currency];
    if (rate == null)
      throw StateError('No exchange rate available for $currency');
    return amount * rate;
  }

  void close() => _client.close();
}

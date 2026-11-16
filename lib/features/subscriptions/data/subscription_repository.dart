import '../domain/payment_method_model.dart';
import '../domain/subscription_model.dart';
import 'app_database.dart';

class SubscriptionRepository {
  SubscriptionRepository(this.database);

  final AppDatabase database;

  Future<List<Subscription>> getSubscriptions() async {
    final rows = await database.selectSql(
      'SELECT * FROM subscriptions ORDER BY next_billing_date',
    );
    return rows.map(Subscription.fromMap).toList();
  }

  Future<void> saveSubscription(Subscription item) async {
    final values = item.toMap();
    final columns = values.keys.join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    await database.insert(
      'INSERT OR REPLACE INTO subscriptions ($columns) VALUES ($placeholders)',
      values.values.toList(),
    );
  }

  Future<void> deleteSubscription(String id) async {
    await database.executeUpdate('DELETE FROM subscriptions WHERE id = ?', [
      id,
    ]);
  }

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final rows = await database.selectSql(
      'SELECT * FROM payment_methods ORDER BY name',
    );
    return rows.map(PaymentMethod.fromMap).toList();
  }

  Future<void> savePaymentMethod(PaymentMethod method) async {
    await database.insert(
      'INSERT OR REPLACE INTO payment_methods(id, name, last_four, color_hex) VALUES (?, ?, ?, ?)',
      [method.id, method.name, method.lastFour, method.colorHex],
    );
  }

  Future<void> deletePaymentMethod(String id) async {
    await database.executeUpdate('DELETE FROM payment_methods WHERE id = ?', [
      id,
    ]);
  }

  Future<String> getSetting(String key, {String fallback = ''}) async {
    final rows = await database.selectSql(
      'SELECT value FROM app_settings WHERE key = ?',
      [key],
    );
    return rows.isEmpty ? fallback : rows.first['value']! as String;
  }

  Future<void> setSetting(String key, String value) async {
    await database.insert(
      'INSERT OR REPLACE INTO app_settings(key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  Future<void> removeSetting(String key) async {
    await database.executeUpdate('DELETE FROM app_settings WHERE key = ?', [
      key,
    ]);
  }

  Future<Map<String, String>> getSettings() async {
    final rows = await database.selectSql(
      'SELECT key, value FROM app_settings',
    );
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  Future<Map<String, double>> getExchangeRates() async {
    final rows = await database.selectSql(
      'SELECT currency_code, rate FROM exchange_rates',
    );
    return {
      for (final row in rows)
        row['currency_code']! as String: (row['rate']! as num).toDouble(),
    };
  }

  Future<void> saveExchangeRates(Map<String, double> rates) async {
    for (final entry in rates.entries) {
      await database.insert(
        'INSERT OR REPLACE INTO exchange_rates(currency_code, rate, updated_at) VALUES (?, ?, ?)',
        [entry.key, entry.value, DateTime.now().toIso8601String()],
      );
    }
  }
}

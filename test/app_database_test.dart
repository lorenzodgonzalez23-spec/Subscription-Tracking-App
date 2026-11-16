import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subglass/features/subscriptions/data/app_database.dart';
import 'package:subglass/features/subscriptions/data/subscription_repository.dart';
import 'package:subglass/features/subscriptions/domain/payment_method_model.dart';
import 'package:subglass/features/subscriptions/domain/subscription_model.dart';

void main() {
  test(
    'persists subscriptions, payment methods, settings, and exchange rates',
    () async {
      final databaseExecutor = NativeDatabase.memory();
      final database = AppDatabase(queryExecutor: databaseExecutor);
      final repository = SubscriptionRepository(database);
      final now = DateTime(2026, 1, 1);
      final subscription = Subscription(
        id: 'subscription-1',
        name: 'Cloud',
        amount: 10,
        currencyCode: 'USD',
        frequency: BillingFrequency.monthly,
        category: 'Cloud Storage',
        nextBillingDate: now,
        isAutoRenew: true,
        reminderDaysBefore: 3,
        createdAt: now,
      );
      const method = PaymentMethod(
        id: 'payment-1',
        name: 'GCash',
        lastFour: '1234',
        colorHex: 0xFF0A84FF,
      );

      try {
        await repository.saveSubscription(subscription);
        await repository.savePaymentMethod(method);
        await repository.setSetting('monthly_budget', '5000');
        await repository.saveExchangeRates({'PHP': 1, 'USD': 56.5});

        expect(
          (await repository.getSubscriptions()).single.toMap(),
          subscription.toMap(),
        );
        expect(
          (await repository.getPaymentMethods()).single.toMap(),
          method.toMap(),
        );
        expect(await repository.getSetting('monthly_budget'), '5000');
        expect(await repository.getExchangeRates(), {'PHP': 1, 'USD': 56.5});

        await repository.deleteSubscription(subscription.id);
        expect(await repository.getSubscriptions(), isEmpty);
      } finally {
        await database.close();
      }
    },
  );
}

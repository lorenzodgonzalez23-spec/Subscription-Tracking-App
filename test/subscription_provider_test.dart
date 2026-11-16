import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subglass/features/subscriptions/data/app_database.dart';
import 'package:subglass/features/subscriptions/data/subscription_repository.dart';
import 'package:subglass/features/subscriptions/domain/subscription_model.dart';
import 'package:subglass/features/subscriptions/presentation/providers/subscription_provider.dart';

void main() {
  test(
    'keeps subscriptions due today and advances invalid custom cycles',
    () async {
      final database = AppDatabase(queryExecutor: NativeDatabase.memory());
      final repository = SubscriptionRepository(database);
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      final dueToday = Subscription(
        id: 'due-today',
        name: 'Due today',
        amount: 10,
        currencyCode: 'PHP',
        frequency: BillingFrequency.monthly,
        category: 'Other',
        nextBillingDate: startOfToday,
        isAutoRenew: true,
        reminderDaysBefore: 1,
        createdAt: startOfToday,
      );
      final invalidCustomCycle = Subscription(
        id: 'invalid-cycle',
        name: 'Invalid cycle',
        amount: 10,
        currencyCode: 'PHP',
        frequency: BillingFrequency.custom,
        customIntervalDays: 0,
        category: 'Other',
        nextBillingDate: startOfToday.subtract(const Duration(days: 1)),
        isAutoRenew: true,
        reminderDaysBefore: 1,
        createdAt: startOfToday,
      );

      try {
        await repository.saveSubscription(dueToday);
        await repository.saveSubscription(invalidCustomCycle);
        final notifier = SubscriptionListNotifier(repository);
        await notifier.reload();
        final subscriptions = await repository.getSubscriptions();

        expect(
          subscriptions
              .singleWhere((item) => item.id == dueToday.id)
              .nextBillingDate,
          startOfToday,
        );
        expect(
          subscriptions
              .singleWhere((item) => item.id == invalidCustomCycle.id)
              .nextBillingDate,
          DateTime(
            startOfToday.year,
            startOfToday.month,
            startOfToday.day + 29,
          ),
        );
        notifier.dispose();
      } finally {
        await database.close();
      }
    },
  );
}

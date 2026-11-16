import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/subscription_repository.dart';
import '../../domain/subscription_model.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => throw StateError('SubscriptionRepository was not provided'),
);

final subscriptionListProvider =
    StateNotifierProvider<
      SubscriptionListNotifier,
      AsyncValue<List<Subscription>>
    >(
      (ref) =>
          SubscriptionListNotifier(ref.watch(subscriptionRepositoryProvider)),
    );

class SubscriptionListNotifier
    extends StateNotifier<AsyncValue<List<Subscription>>> {
  SubscriptionListNotifier(this.repository) : super(const AsyncLoading()) {
    reload();
  }

  final SubscriptionRepository repository;

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await repository.getSubscriptions();
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      for (final item in items) {
        if (!item.isAutoRenew || !item.nextBillingDate.isBefore(startOfToday)) {
          continue;
        }
        var date = item.nextBillingDate;
        while (!date.isAfter(startOfToday)) {
          date = _nextBillingDate(item, date);
        }
        await repository.saveSubscription(
          Subscription(
            id: item.id,
            name: item.name,
            amount: item.amount,
            currencyCode: item.currencyCode,
            frequency: item.frequency,
            customIntervalDays: item.customIntervalDays,
            category: item.category,
            customImagePath: item.customImagePath,
            fallbackColorHex: item.fallbackColorHex,
            nextBillingDate: date,
            isAutoRenew: item.isAutoRenew,
            reminderDaysBefore: item.reminderDaysBefore,
            paymentMethodId: item.paymentMethodId,
            createdAt: item.createdAt,
          ),
        );
      }
      return repository.getSubscriptions();
    });
  }

  Future<void> save(Subscription item) async {
    await repository.saveSubscription(item);
    await reload();
  }

  DateTime _nextBillingDate(Subscription item, DateTime from) {
    switch (item.frequency) {
      case BillingFrequency.daily:
        return from.add(const Duration(days: 1));
      case BillingFrequency.weekly:
        return from.add(const Duration(days: 7));
      case BillingFrequency.monthly:
        return _addMonths(from, 1);
      case BillingFrequency.quarterly:
        return _addMonths(from, 3);
      case BillingFrequency.semiAnnual:
        return _addMonths(from, 6);
      case BillingFrequency.yearly:
        return _addMonths(from, 12);
      case BillingFrequency.custom:
        final interval = item.customIntervalDays;
        return from.add(
          Duration(days: interval != null && interval > 0 ? interval : 30),
        );
    }
  }

  DateTime _addMonths(DateTime from, int months) {
    final monthIndex = from.month - 1 + months;
    final year = from.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      from.day.clamp(1, lastDay),
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
      from.microsecond,
    );
  }

  Future<void> delete(Subscription item) async {
    await repository.deleteSubscription(item.id);
    await reload();
  }
}

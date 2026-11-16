import 'package:flutter_test/flutter_test.dart';
import 'package:subglass/features/subscriptions/domain/subscription_model.dart';

Subscription subscription(BillingFrequency frequency, {int? days}) =>
    Subscription(
      id: 'test',
      name: 'Test',
      amount: 12,
      currencyCode: 'PHP',
      frequency: frequency,
      customIntervalDays: days,
      category: 'Other',
      nextBillingDate: DateTime(2026, 1, 1),
      isAutoRenew: true,
      reminderDaysBefore: 1,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('normalizes each supported billing cycle to a monthly amount', () {
    expect(
      subscription(BillingFrequency.daily).monthlyEquivalentInOriginalCurrency,
      closeTo(12 * 30.4375, 0.0001),
    );
    expect(
      subscription(BillingFrequency.weekly).monthlyEquivalentInOriginalCurrency,
      closeTo(12 * 4.345, 0.0001),
    );
    expect(
      subscription(
        BillingFrequency.monthly,
      ).monthlyEquivalentInOriginalCurrency,
      12,
    );
    expect(
      subscription(
        BillingFrequency.quarterly,
      ).monthlyEquivalentInOriginalCurrency,
      4,
    );
    expect(
      subscription(
        BillingFrequency.semiAnnual,
      ).monthlyEquivalentInOriginalCurrency,
      2,
    );
    expect(
      subscription(BillingFrequency.yearly).monthlyEquivalentInOriginalCurrency,
      1,
    );
  });

  test('custom interval defaults safely and honors positive day intervals', () {
    expect(
      subscription(BillingFrequency.custom).monthlyEquivalentInOriginalCurrency,
      closeTo(12 / 30 * 30.4375, 0.0001),
    );
    expect(
      subscription(
        BillingFrequency.custom,
        days: 15,
      ).monthlyEquivalentInOriginalCurrency,
      closeTo(24.35, 0.0001),
    );
  });
}

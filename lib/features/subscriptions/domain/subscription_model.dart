enum BillingFrequency {
  daily,
  weekly,
  monthly,
  quarterly,
  semiAnnual,
  yearly,
  custom,
}

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.currencyCode,
    required this.frequency,
    required this.category,
    required this.nextBillingDate,
    required this.isAutoRenew,
    required this.reminderDaysBefore,
    required this.createdAt,
    this.customIntervalDays,
    this.customImagePath,
    this.fallbackColorHex = 0xFF0A84FF,
    this.fallbackIconCode = 0,
    this.paymentMethodId,
  });

  final String id;
  final String name;
  final double amount;
  final String currencyCode;
  final BillingFrequency frequency;
  final int? customIntervalDays;
  final String category;
  final String? customImagePath;
  final int fallbackColorHex;
  final int fallbackIconCode;
  final DateTime nextBillingDate;
  final bool isAutoRenew;
  final int reminderDaysBefore;
  final String? paymentMethodId;
  final DateTime createdAt;

  double get monthlyEquivalentInOriginalCurrency {
    switch (frequency) {
      case BillingFrequency.daily:
        return amount * 30.4375;
      case BillingFrequency.weekly:
        return amount * 4.345;
      case BillingFrequency.monthly:
        return amount;
      case BillingFrequency.quarterly:
        return amount / 3;
      case BillingFrequency.semiAnnual:
        return amount / 6;
      case BillingFrequency.yearly:
        return amount / 12;
      case BillingFrequency.custom:
        final days = customIntervalDays != null && customIntervalDays! > 0
            ? customIntervalDays!
            : 30;
        return amount / days * 30.4375;
    }
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'currency_code': currencyCode,
    'frequency': frequency.name,
    'custom_interval_days': customIntervalDays,
    'category': category,
    'custom_image_path': customImagePath,
    'fallback_color_hex': fallbackColorHex,
    'fallback_icon_code': fallbackIconCode,
    'next_billing_date': nextBillingDate.toIso8601String(),
    'is_auto_renew': isAutoRenew ? 1 : 0,
    'reminder_days_before': reminderDaysBefore,
    'payment_method_id': paymentMethodId,
    'created_at': createdAt.toIso8601String(),
  };

  factory Subscription.fromMap(Map<String, Object?> map) => Subscription(
    id: map['id']! as String,
    name: map['name']! as String,
    amount: (map['amount']! as num).toDouble(),
    currencyCode: map['currency_code']! as String,
    frequency: BillingFrequency.values.byName(map['frequency']! as String),
    customIntervalDays: map['custom_interval_days'] as int?,
    category: map['category']! as String,
    customImagePath: map['custom_image_path'] as String?,
    fallbackColorHex: map['fallback_color_hex']! as int,
    fallbackIconCode: (map['fallback_icon_code'] as int?) ?? 0,
    nextBillingDate: DateTime.parse(map['next_billing_date']! as String),
    isAutoRenew: map['is_auto_renew'] == 1,
    reminderDaysBefore: map['reminder_days_before']! as int,
    paymentMethodId: map['payment_method_id'] as String?,
    createdAt: DateTime.parse(map['created_at']! as String),
  );
}

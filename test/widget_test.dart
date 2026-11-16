import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subglass/features/subscriptions/data/app_database.dart';
import 'package:subglass/features/subscriptions/data/subscription_repository.dart';
import 'package:subglass/features/subscriptions/domain/payment_method_model.dart';
import 'package:subglass/features/subscriptions/domain/subscription_model.dart';
import 'package:subglass/features/subscriptions/presentation/providers/budget_provider.dart';
import 'package:subglass/features/subscriptions/presentation/providers/exchange_rate_provider.dart';
import 'package:subglass/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:subglass/main.dart';

class _MemoryRepository extends SubscriptionRepository {
  _MemoryRepository() : super(AppDatabase());

  @override
  Future<String> getSetting(String key, {String fallback = ''}) async =>
      key == 'base_currency' ? 'PHP' : fallback;

  @override
  Future<List<Subscription>> getSubscriptions() async => [];

  @override
  Future<List<PaymentMethod>> getPaymentMethods() async => [];

  @override
  Future<Map<String, double>> getExchangeRates() async => {'PHP': 1};
}

final _memoryRepository = _MemoryRepository();

void main() {
  testWidgets('dashboard starts with the local-first empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(_memoryRepository),
          exchangeRatesProvider.overrideWith((ref) async => {'PHP': 1}),
          monthlyBudgetProvider.overrideWith((ref) async => 0),
        ],
        child: const SubGlassApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SubGlass'), findsOneWidget);
    expect(find.text('Recurring spend'), findsOneWidget);
    expect(
      find.text('No subscriptions yet. Add one to get started.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('subscription form fits a narrow screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(_memoryRepository),
          exchangeRatesProvider.overrideWith((ref) async => {'PHP': 1}),
          monthlyBudgetProvider.overrideWith((ref) async => 0),
        ],
        child: const SubGlassApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add subscription'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(DropdownButtonFormField<String>).first).width,
      greaterThan(120),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('subscription amount rejects non-finite values', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(_memoryRepository),
          exchangeRatesProvider.overrideWith((ref) async => {'PHP': 1}),
          monthlyBudgetProvider.overrideWith((ref) async => 0),
        ],
        child: const SubGlassApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add subscription'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'NaN');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a positive amount'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/backup_export_service.dart';
import '../../../../core/services/exchange_rate_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/local_file_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/app_database.dart';
import '../../data/subscription_repository.dart';
import '../../domain/payment_method_model.dart';
import '../../domain/subscription_model.dart';
import '../providers/subscription_provider.dart';
import '../providers/payment_method_provider.dart';
import '../providers/exchange_rate_provider.dart';
import '../providers/budget_provider.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/payment_method_filter.dart';
import '../widgets/spend_summary_card.dart';
import '../widgets/upcoming_renewals_strip.dart';
import 'add_edit_subscription_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _categoryFilter;
  String? _paymentFilter;
  bool _yearlyView = false;
  late Future<_DashboardSettings> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  Future<_DashboardSettings> _loadSettings() async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final currency = await repository.getSetting(
      'base_currency',
      fallback: 'PHP',
    );
    final rates = <String, double>{'PHP': 1};
    for (final code in const [
      'PHP',
      'USD',
      'EUR',
      'JPY',
      'GBP',
      'SGD',
      'AUD',
      'CAD',
    ]) {
      final manual = await repository.getSetting(
        'manual_rate_$code',
        fallback: '',
      );
      final value = double.tryParse(manual);
      if (value != null && value.isFinite && value > 0) rates[code] = value;
    }
    rates.putIfAbsent('PHP', () => 1);
    return _DashboardSettings(currency, rates);
  }

  void _reload() {
    ref.read(subscriptionListProvider.notifier).reload();
    ref.read(paymentMethodsProvider.notifier).reload();
    ref.invalidate(exchangeRatesProvider);
    ref.invalidate(monthlyBudgetProvider);
    setState(() {
      _settingsFuture = _loadSettings();
    });
  }

  Future<void> _openSettings(
    SubscriptionRepository repository,
    AppDatabase database,
    List<PaymentMethod> methods,
    Map<String, double> rates,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => SettingsScreen(
        repository: repository,
        database: database,
        methods: methods,
        rates: rates,
        onChanged: _reload,
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _addOrEdit(
    SubscriptionRepository repository,
    List<PaymentMethod> methods, {
    Subscription? existing,
  }) async {
    final item = await showDialog<Subscription>(
      context: context,
      builder: (context) =>
          AddEditSubscriptionScreen(methods: methods, subscription: existing),
    );
    if (item == null) return;
    await NotificationService.cancel(item);
    await ref.read(subscriptionListProvider.notifier).save(item);
    final methodName =
        methods
            .where((method) => method.id == item.paymentMethodId)
            .map((method) => method.name)
            .firstOrNull ??
        '';
    await NotificationService.schedule(item, methodName);
  }

  Future<void> _delete(Subscription item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subscription?'),
        content: Text('Remove ${item.name} from your tracker?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationService.cancel(item);
      await ref.read(subscriptionListProvider.notifier).delete(item);
    }
  }

  Future<void> _refreshRates(SubscriptionRepository repository) async {
    final service = ExchangeRateService(repository);
    try {
      await service.loadRates(refresh: true);
      ref.invalidate(exchangeRatesProvider);
      if (mounted) {
        setState(() {
          _settingsFuture = _loadSettings();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh exchange rates: $error')),
        );
      }
    } finally {
      service.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(subscriptionListProvider, (_, next) {
      final items = next.valueOrNull;
      if (items != null) {
        unawaited(
          _syncNotifications(
            items,
            ref.read(paymentMethodsProvider).valueOrNull ?? const [],
          ),
        );
      }
    });
    ref.listen(paymentMethodsProvider, (_, next) {
      final methods = next.valueOrNull;
      final items = ref.read(subscriptionListProvider).valueOrNull;
      if (methods != null && items != null) {
        unawaited(_syncNotifications(items, methods));
      }
    });
    final repository = ref.watch(subscriptionRepositoryProvider);
    final listState = ref.watch(subscriptionListProvider);
    final methodState = ref.watch(paymentMethodsProvider);
    final ratesState = ref.watch(exchangeRatesProvider);
    final budgetState = ref.watch(monthlyBudgetProvider);
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 600;
    final database = repository.database;
    final methods = methodState.valueOrNull ?? const <PaymentMethod>[];
    final rates = ratesState.valueOrNull ?? const <String, double>{'PHP': 1};
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SubGlass',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh exchange rates',
            onPressed: () => _refreshRates(repository),
            icon: const Icon(Icons.currency_exchange),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () =>
                _openSettings(repository, database, methods, rates),
            icon: const Icon(Icons.tune),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(repository, methods),
        icon: const Icon(Icons.add),
        label: const Text('Add subscription'),
      ),
      bottomNavigationBar: desktop
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 10),
                borderRadius: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Icon(Icons.dashboard_rounded, color: AppColors.blue),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () =>
                          _openSettings(repository, database, methods, rates),
                      icon: const Icon(Icons.tune),
                    ),
                    IconButton(
                      tooltip: 'Export CSV',
                      onPressed: () async {
                        try {
                          final items =
                              listState.valueOrNull ?? const <Subscription>[];
                          final paymentNames = {
                            for (final method in methods)
                              method.id: method.name,
                          };
                          await BackupExportService(
                            database,
                            repository,
                          ).exportCsv(items, rates, paymentNames);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('CSV export failed: $error'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.file_download_outlined),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (desktop)
              NavigationRail(
                selectedIndex: 0,
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: Text('Overview'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.tune),
                    label: Text('Settings'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.file_download_outlined),
                    label: Text('Export'),
                  ),
                ],
                onDestinationSelected: (index) {
                  if (index == 1) {
                    _openSettings(repository, database, methods, rates);
                  } else if (index == 2) {
                    _exportCsv(repository, database, methods, rates, listState);
                  }
                },
              ),
            Expanded(
              child: listState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Could not load subscriptions: $error',
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
                data: (items) => FutureBuilder<_DashboardSettings>(
                  future: _settingsFuture,
                  builder: (context, settingsSnapshot) {
                    if (settingsSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load settings: ${settingsSnapshot.error}',
                        ),
                      );
                    }
                    if (!settingsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final settings = settingsSnapshot.data!;
                    final mergedRates = {...rates, ...settings.rates};
                    return budgetState.when(
                      data: (budget) => _dashboardContent(
                        items,
                        methods,
                        mergedRates,
                        settings,
                        budget,
                        desktop,
                        repository,
                        database,
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) =>
                          Center(child: Text('Could not load budget: $error')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNotifications(
    List<Subscription> items,
    List<PaymentMethod> methods,
  ) async {
    try {
      for (final item in items) {
        final methodName =
            methods
                .where((method) => method.id == item.paymentMethodId)
                .map((method) => method.name)
                .firstOrNull ??
            '';
        await NotificationService.cancel(item);
        await NotificationService.schedule(item, methodName);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not schedule renewal reminders: $error'),
          ),
        );
      }
    }
  }

  Widget _dashboardContent(
    List<Subscription> allItems,
    List<PaymentMethod> methods,
    Map<String, double> rates,
    _DashboardSettings settings,
    double budget,
    bool desktop,
    SubscriptionRepository repository,
    AppDatabase database,
  ) {
    final items = allItems
        .where(
          (item) =>
              _paymentFilter == null || item.paymentMethodId == _paymentFilter,
        )
        .toList();
    final filtered = items
        .where(
          (item) => _categoryFilter == null || item.category == _categoryFilter,
        )
        .toList();
    final missingRates = items
        .where((item) => !rates.containsKey(item.currencyCode))
        .map((item) => item.currencyCode)
        .toSet();
    final baseRate = rates[settings.currency];
    final canCalculate =
        missingRates.isEmpty && baseRate != null && baseRate > 0;
    double monthlyFor(Subscription item) =>
        item.monthlyEquivalentInOriginalCurrency *
        (rates[item.currencyCode] ?? 0) /
        (baseRate ?? 1);
    final monthly = items.fold<double>(
      0,
      (total, item) => total + monthlyFor(item),
    );
    final categoryTotals = <String, double>{};
    for (final item in items) {
      categoryTotals.update(
        item.category,
        (value) => value + monthlyFor(item),
        ifAbsent: () => monthlyFor(item),
      );
    }
    final subscriptionsPanel = _subscriptionsPanel(
      filtered,
      methods,
      rates,
      settings,
      repository,
      allItems,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopLayout = desktop && constraints.maxWidth >= 600;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            desktopLayout ? 28 : 18,
            12,
            desktopLayout ? 28 : 18,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canCalculate && items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: AppColors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Totals need exchange rates for ${missingRates.join(', ')}'
                            '${baseRate == null ? ' and ${settings.currency}' : ''}. '
                            'Connect to the internet or set a manual rate in Settings.',
                            style: const TextStyle(color: AppColors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (desktopLayout)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          if (canCalculate)
                            SpendSummaryCard(
                              monthly: monthly,
                              yearly: monthly * 12,
                              budget: budget,
                              yearlyView: _yearlyView,
                              currency: settings.currency,
                              onViewChanged: (value) =>
                                  setState(() => _yearlyView = value),
                            ),
                          const SizedBox(height: 18),
                          CategoryPieChart(
                            values: categoryTotals,
                            selectedCategory: _categoryFilter,
                            currency: settings.currency,
                            onCategorySelected: (value) =>
                                setState(() => _categoryFilter = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UpcomingRenewalsStrip(items: items),
                          const SizedBox(height: 18),
                          _filterAndList(
                            subscriptionsPanel,
                            methods,
                            filtered,
                            settings,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                if (canCalculate)
                  SpendSummaryCard(
                    monthly: monthly,
                    yearly: monthly * 12,
                    budget: budget,
                    yearlyView: _yearlyView,
                    currency: settings.currency,
                    onViewChanged: (value) =>
                        setState(() => _yearlyView = value),
                  ),
                const SizedBox(height: 18),
                UpcomingRenewalsStrip(items: items),
                const SizedBox(height: 18),
                CategoryPieChart(
                  values: categoryTotals,
                  selectedCategory: _categoryFilter,
                  currency: settings.currency,
                  onCategorySelected: (value) =>
                      setState(() => _categoryFilter = value),
                ),
                const SizedBox(height: 22),
                _filterAndList(subscriptionsPanel, methods, filtered, settings),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _filterAndList(
    Widget panel,
    List<PaymentMethod> methods,
    List<Subscription> items,
    _DashboardSettings settings,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Subscriptions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          if (_categoryFilter != null)
            TextButton(
              onPressed: () => setState(() => _categoryFilter = null),
              child: const Text('Clear category'),
            ),
        ],
      ),
      const SizedBox(height: 8),
      PaymentMethodFilter(
        methods: methods,
        selectedId: _paymentFilter,
        onSelected: (value) => setState(() => _paymentFilter = value),
      ),
      const SizedBox(height: 10),
      panel,
    ],
  );

  Widget _subscriptionsPanel(
    List<Subscription> items,
    List<PaymentMethod> methods,
    Map<String, double> rates,
    _DashboardSettings settings,
    SubscriptionRepository repository,
    List<Subscription> allItems,
  ) {
    if (items.isEmpty) {
      return GlassContainer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              allItems.isEmpty
                  ? 'No subscriptions yet. Add one to get started.'
                  : 'No subscriptions match these filters.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              Divider(height: 1, color: Colors.white.withOpacity(0.06)),
            FutureBuilder<Uint8List?>(
              future: items[index].customImagePath == null
                  ? Future.value(null)
                  : LocalFileStore.read(items[index].customImagePath!),
              builder: (context, snapshot) {
                final item = items[index];
                final method = methods
                    .where((element) => element.id == item.paymentMethodId)
                    .map((element) => element.name)
                    .firstOrNull;
                final monthly =
                    item.monthlyEquivalentInOriginalCurrency *
                    (rates[item.currencyCode] ?? 1);
                final baseRate = rates[settings.currency] ?? 1;
                return SubscriptionTile(
                  name: item.name,
                  subtitle:
                      '${item.category} · ${item.frequency.name}'
                      '${method == null ? '' : ' · $method'}',
                  amount:
                      canFormatAmount(
                        rates,
                        settings.currency,
                        item.currencyCode,
                      )
                      ? CurrencyFormatter.format(
                          monthly / baseRate,
                          settings.currency,
                        )
                      : CurrencyFormatter.format(
                          item.amount,
                          item.currencyCode,
                        ),
                  color: Color(item.fallbackColorHex),
                  autoRenew: item.isAutoRenew,
                  imageBytes: snapshot.data,
                  iconCode: item.fallbackIconCode,
                  onTap: () => _addOrEdit(repository, methods, existing: item),
                  onDelete: () => _delete(item),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    SubscriptionRepository repository,
    AppDatabase database,
    List<PaymentMethod> methods,
    Map<String, double> rates,
    AsyncValue<List<Subscription>> listState,
  ) async {
    try {
      final names = {for (final method in methods) method.id: method.name};
      await BackupExportService(
        database,
        repository,
      ).exportCsv(listState.valueOrNull ?? const [], rates, names);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV export failed: $error')));
      }
    }
  }
}

bool canFormatAmount(
  Map<String, double> rates,
  String baseCurrency,
  String currency,
) => rates.containsKey(baseCurrency) && rates.containsKey(currency);

class _DashboardSettings {
  const _DashboardSettings(this.currency, this.rates);
  final String currency;
  final Map<String, double> rates;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

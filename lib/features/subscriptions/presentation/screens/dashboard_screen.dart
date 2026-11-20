import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/exchange_rate_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/subscription_repository.dart';
import '../../domain/payment_method_model.dart';
import '../../domain/subscription_model.dart';
import '../providers/budget_provider.dart';
import '../providers/exchange_rate_provider.dart';
import '../providers/payment_method_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/fallback_icons.dart';
import 'add_edit_subscription_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  String _search = '';
  String _categoryFilter = 'All';
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
    return _DashboardSettings(currency, rates);
  }

  void _reload() {
    ref.read(subscriptionListProvider.notifier).reload();
    ref.read(paymentMethodsProvider.notifier).reload();
    ref.invalidate(exchangeRatesProvider);
    ref.invalidate(monthlyBudgetProvider);
    setState(() => _settingsFuture = _loadSettings());
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
      if (mounted) setState(() => _settingsFuture = _loadSettings());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not refresh exchange rates: $error'),
          ),
        );
      }
    } finally {
      service.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(subscriptionRepositoryProvider);
    final listState = ref.watch(subscriptionListProvider);
    final methodState = ref.watch(paymentMethodsProvider);
    final ratesState = ref.watch(exchangeRatesProvider);
    final budgetState = ref.watch(monthlyBudgetProvider);
    final methods = methodState.valueOrNull ?? const <PaymentMethod>[];
    final liveRates =
        ratesState.valueOrNull ?? const <String, double>{'PHP': 1};

    return Scaffold(
      body: SafeArea(
        child: listState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Could not load subscriptions: $error'),
          ),
          data: (items) => FutureBuilder<_DashboardSettings>(
            future: _settingsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final settings = snapshot.data!;
              final rates = {...liveRates, ...settings.rates};
              return budgetState.when(
                data: (budget) => switch (_selectedIndex) {
                  0 => _overviewPage(
                      items,
                      methods,
                      rates,
                      settings.currency,
                      budget,
                      repository,
                    ),
                  1 => _subscriptionsPage(
                      items,
                      methods,
                      rates,
                      settings.currency,
                      repository,
                    ),
                  _ => SettingsScreen(
                      repository: repository,
                      database: repository.database,
                      methods: methods,
                      rates: rates,
                      onChanged: _reload,
                    ),
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Could not load budget: $error'),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: Icon(Icons.format_list_bulleted),
            label: 'Subscriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  double _monthlyFor(
    Subscription item,
    Map<String, double> rates,
    String currency,
  ) {
    final baseRate = rates[currency] ?? 1;
    return item.monthlyEquivalentInOriginalCurrency *
        (rates[item.currencyCode] ?? 0) /
        baseRate;
  }

  double _billingAmountFor(
    Subscription item,
    Map<String, double> rates,
    String currency,
  ) {
    final baseRate = rates[currency] ?? 1;
    return item.amount *
        (rates[item.currencyCode] ?? 0) /
        baseRate;
  }

  Widget _overviewPage(
    List<Subscription> items,
    List<PaymentMethod> methods,
    Map<String, double> rates,
    String currency,
    double budget,
    SubscriptionRepository repository,
  ) {
    final monthly = items.fold<double>(
      0,
      (total, item) => total + _monthlyFor(item, rates, currency),
    );
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));
    final upcoming = items
        .where(
          (item) =>
              !item.nextBillingDate.isBefore(now) &&
              !item.nextBillingDate.isAfter(horizon),
        )
        .toList()
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    final upcomingTotal = upcoming.fold<double>(
      0,
      (total, item) => total + _billingAmountFor(item, rates, currency),
    );
    final budgetRemaining = budget - monthly;
    final budgetRatio =
        budget > 0 ? (monthly / budget).clamp(0.0, 1.0).toDouble() : 0.0;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Orbit'),
          actions: [
            IconButton(
              tooltip: 'Refresh exchange rates',
              onPressed: () => _refreshRates(repository),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                'Your money, in orbit.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Friday, ${_monthName(now.month)} ${now.day}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MONTHLY SPEND',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          '${_monthName(now.month).toUpperCase()} ${now.year}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(monthly, currency),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A little clarity. A lot more control.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${items.length} active subscriptions',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          '${CurrencyFormatter.format(monthly * 12, currency)} / year',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly budget',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    '${CurrencyFormatter.format(monthly, currency)} of ${CurrencyFormatter.format(budget, currency)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: budgetRatio,
                  minHeight: 6,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${CurrencyFormatter.format(budgetRemaining, currency)} left in your budget',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Coming up',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Next 7 days',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${upcoming.length} renewals · ${CurrencyFormatter.format(upcomingTotal, currency)} total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (upcoming.isEmpty)
                _emptyCard('No renewals in the next 7 days')
              else
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < upcoming.length; i++)
                        _subscriptionTile(
                          upcoming[i],
                          methods,
                          rates,
                          currency,
                          repository,
                          renewalLabel: 'Renews ${_dateLabel(upcoming[i].nextBillingDate)}',
                          showDivider: i > 0,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _addOrEdit(repository, methods),
                  icon: const Icon(Icons.add),
                  label: const Text('Add subscription'),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _subscriptionsPage(
    List<Subscription> items,
    List<PaymentMethod> methods,
    Map<String, double> rates,
    String currency,
    SubscriptionRepository repository,
  ) {
    var filtered = items.where((item) {
      final matchesSearch =
          _search.isEmpty ||
          item.name.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory =
          _categoryFilter == 'All' || item.category == _categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
    filtered.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    final monthly = filtered.fold<double>(
      0,
      (total, item) => total + _monthlyFor(item, rates, currency),
    );

    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Subscriptions')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SearchBar(
                hintText: 'Search subscriptions',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in const [
                      'All',
                      'Entertainment',
                      'Tools',
                      'Productivity & AI',
                      'Utilities',
                      'Health & Fitness',
                      'Cloud Storage',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            category == 'All'
                                ? 'All ${items.length}'
                                : category,
                          ),
                          selected: _categoryFilter == category,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _categoryFilter = category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Everything you’re subscribed to',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${filtered.length} active · ${CurrencyFormatter.format(monthly, currency)} per month',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                _emptyCard(
                  items.isEmpty
                      ? 'No subscriptions yet. Add one to get started.'
                      : 'No subscriptions match these filters.',
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++)
                        _subscriptionTile(
                          filtered[i],
                          methods,
                          rates,
                          currency,
                          repository,
                          renewalLabel:
                              '${filtered[i].category} · ${_dateLabel(filtered[i].nextBillingDate)}',
                          showDivider: i > 0,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _addOrEdit(repository, methods),
                  icon: const Icon(Icons.add),
                  label: const Text('Add subscription'),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sorted by next renewal · All amounts in $currency',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _subscriptionTile(
    Subscription item,
    List<PaymentMethod> methods,
    Map<String, double> rates,
    String currency,
    SubscriptionRepository repository, {
    required String renewalLabel,
    required bool showDivider,
  }) {
    final amount = _billingAmountFor(item, rates, currency);
    return Container(
      decoration: showDivider
          ? null
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _addOrEdit(repository, methods, existing: item),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Color(item.fallbackColorHex).withOpacity(0.18),
          child: Icon(
            fallbackIconFor(item.fallbackIconCode),
            color: Color(item.fallbackColorHex),
          ),
        ),
        title: Text(
          item.name,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          renewalLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Text(
          CurrencyFormatter.format(amount, currency),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        onLongPress: () => _delete(item),
      ),
    );
  }

  Widget _emptyCard(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = target.difference(today).inDays;
    if (difference == 0) return 'today';
    if (difference == 1) return 'tomorrow';
    return '${_monthName(date.month).substring(0, 3)} ${date.day}';
  }
}

class _DashboardSettings {
  const _DashboardSettings(this.currency, this.rates);

  final String currency;
  final Map<String, double> rates;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

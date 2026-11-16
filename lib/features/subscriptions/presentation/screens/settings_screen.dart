import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/backup_export_service.dart';
import '../../../../core/services/exchange_rate_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../data/subscription_repository.dart';
import '../../domain/payment_method_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.repository,
    required this.database,
    required this.methods,
    required this.rates,
    required this.onChanged,
    super.key,
  });

  final SubscriptionRepository repository;
  final AppDatabase database;
  final List<PaymentMethod> methods;
  final Map<String, double> rates;
  final VoidCallback onChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _currencies = [
    'PHP',
    'USD',
    'EUR',
    'JPY',
    'GBP',
    'SGD',
    'AUD',
    'CAD',
  ];
  final _budgetController = TextEditingController();
  final _manualRateController = TextEditingController();
  String _baseCurrency = 'PHP';
  String _overrideCurrency = 'USD';
  late Map<String, double> _rates;
  late List<PaymentMethod> _methods;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rates = Map.of(widget.rates);
    _methods = List.of(widget.methods);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final budget = await widget.repository.getSetting(
      'monthly_budget',
      fallback: '0',
    );
    final base = await widget.repository.getSetting(
      'base_currency',
      fallback: 'PHP',
    );
    final manual = await widget.repository.getSetting(
      'manual_rate_$_overrideCurrency',
      fallback: '',
    );
    if (!mounted) return;
    setState(() {
      _budgetController.text = budget;
      _baseCurrency = _currencies.contains(base) ? base : 'PHP';
      _manualRateController.text = manual;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || !budget.isFinite || budget < 0) {
      setState(() => _error = 'Enter a valid budget amount.');
      return;
    }
    final enteredRate = _manualRateController.text.trim();
    final rate = enteredRate.isEmpty ? null : double.tryParse(enteredRate);
    if (enteredRate.isNotEmpty &&
        (rate == null || !rate.isFinite || rate <= 0)) {
      setState(() => _error = 'Enter a positive PHP-per-unit exchange rate.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.setSetting('monthly_budget', budget.toString());
      await widget.repository.setSetting('base_currency', _baseCurrency);
      if (rate == null) {
        await widget.repository.removeSetting('manual_rate_$_overrideCurrency');
      } else {
        await widget.repository.setSetting(
          'manual_rate_$_overrideCurrency',
          rate.toString(),
        );
      }
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshRates() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ExchangeRateService(widget.repository);
      try {
        final fresh = await service.loadRates(refresh: true);
        if (!mounted) return;
        setState(() {
          _rates = fresh;
        });
      } finally {
        service.close();
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not refresh rates: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPaymentMethod() async {
    final name = TextEditingController();
    final lastFour = TextEditingController();
    var color = AppColors.blue;
    String? error;
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add payment method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastFour,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Last 4 digits (optional)',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in [
                    AppColors.blue,
                    AppColors.green,
                    AppColors.purple,
                    AppColors.amber,
                    AppColors.red,
                  ])
                    IconButton(
                      onPressed: () => setDialogState(() => color = item),
                      icon: Icon(
                        Icons.circle,
                        color: item,
                        size: color == item ? 28 : 20,
                      ),
                    ),
                ],
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: AppColors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setDialogState(() => error = 'Enter a payment method name.');
                  return;
                }
                if (lastFour.text.isNotEmpty &&
                    !RegExp(r'^\d{4}$').hasMatch(lastFour.text)) {
                  setDialogState(
                    () => error = 'Last 4 digits must be numeric.',
                  );
                  return;
                }
                setDialogState(() => error = null);
                Navigator.pop(
                  context,
                  PaymentMethod(
                    id: const Uuid().v4(),
                    name: name.text.trim(),
                    lastFour: lastFour.text.isEmpty ? null : lastFour.text,
                    colorHex: color.value,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    lastFour.dispose();
    if (method == null) return;
    await widget.repository.savePaymentMethod(method);
    if (mounted) setState(() => _methods = [..._methods, method]);
    widget.onChanged();
  }

  Future<void> _removePaymentMethod(PaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove payment method?'),
        content: Text(
          'Subscriptions tagged "${method.name}" will no longer be tagged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.database.execute(
      'UPDATE subscriptions SET payment_method_id = NULL WHERE payment_method_id = ?',
      [method.id],
    );
    await widget.repository.deletePaymentMethod(method.id);
    if (mounted) {
      setState(() => _methods.removeWhere((value) => value.id == method.id));
    }
    widget.onChanged();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _manualRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Settings'),
    content: SizedBox(
      width: 520,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _baseCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Primary currency',
                    ),
                    items: _currencies
                        .map(
                          (code) =>
                              DropdownMenuItem(value: code, child: Text(code)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _baseCurrency = value ?? 'PHP'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monthly budget ($_baseCurrency)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _overrideCurrency,
                          decoration: const InputDecoration(
                            labelText: 'Override rate for',
                          ),
                          items: _currencies
                              .where((code) => code != 'PHP')
                              .map(
                                (code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(code),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            final code = value ?? 'USD';
                            final manual = await widget.repository.getSetting(
                              'manual_rate_$code',
                              fallback: '',
                            );
                            if (!mounted) return;
                            setState(() {
                              _overrideCurrency = code;
                              _manualRateController.text = manual;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _manualRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'PHP per 1 unit',
                            helperText: _rates[_overrideCurrency] == null
                                ? 'No live rate cached'
                                : 'Live rate: ${_rates[_overrideCurrency]}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _refreshRates,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh live rates'),
                    ),
                  ),
                  const Divider(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Payment methods',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _addPaymentMethod,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (_methods.isEmpty)
                    const Text(
                      'No payment methods added.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  for (final method in _methods)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(method.colorHex),
                      ),
                      title: Text(method.name),
                      subtitle: method.lastFour == null
                          ? null
                          : Text('•••• ${method.lastFour}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removePaymentMethod(method),
                      ),
                    ),
                  const Divider(height: 26),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                try {
                                  await BackupExportService(
                                    widget.database,
                                    widget.repository,
                                  ).exportBackup();
                                } catch (error) {
                                  if (mounted) {
                                    setState(
                                      () => _error = 'Backup failed: $error',
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Export backup'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                try {
                                  await BackupExportService(
                                    widget.database,
                                    widget.repository,
                                  ).importBackup();
                                  widget.onChanged();
                                  if (context.mounted) Navigator.pop(context);
                                } catch (error) {
                                  if (mounted) {
                                    setState(
                                      () => _error = 'Restore failed: $error',
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.unarchive_outlined),
                        label: const Text('Restore backup'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: AppColors.red)),
                  ],
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _loading || _busy ? null : _saveSettings,
        child: _busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save settings'),
      ),
    ],
  );
}

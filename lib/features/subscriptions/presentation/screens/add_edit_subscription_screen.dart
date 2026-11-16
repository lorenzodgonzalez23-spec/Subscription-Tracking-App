import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/local_file_store.dart';
import '../../domain/payment_method_model.dart';
import '../../domain/subscription_model.dart';
import '../widgets/fallback_icons.dart';

class AddEditSubscriptionScreen extends StatefulWidget {
  const AddEditSubscriptionScreen({
    required this.methods,
    this.subscription,
    super.key,
  });

  final List<PaymentMethod> methods;
  final Subscription? subscription;

  @override
  State<AddEditSubscriptionScreen> createState() =>
      _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState extends State<AddEditSubscriptionScreen> {
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
  static const _categories = [
    'Entertainment',
    'Productivity & AI',
    'Utilities',
    'Gaming',
    'Health & Fitness',
    'Cloud Storage',
    'Education',
    'Other',
  ];
  static const _frequencies = {
    BillingFrequency.daily: 'Daily',
    BillingFrequency.weekly: 'Weekly',
    BillingFrequency.monthly: 'Monthly',
    BillingFrequency.quarterly: 'Quarterly',
    BillingFrequency.semiAnnual: 'Every 6 months',
    BillingFrequency.yearly: 'Yearly',
    BillingFrequency.custom: 'Custom',
  };

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _customIntervalController = TextEditingController();
  late String _currency;
  late String _category;
  late BillingFrequency _frequency;
  late DateTime _nextBillingDate;
  late bool _autoRenew;
  late int _reminderDays;
  String? _paymentMethodId;
  String? _imagePath;
  int _color = 0xFF0A84FF;
  int _iconCode = 0;
  String _customUnit = 'days';
  bool _savingImage = false;

  @override
  void initState() {
    super.initState();
    final item = widget.subscription;
    _nameController.text = item?.name ?? '';
    _amountController.text = item?.amount.toString() ?? '';
    _currency = item?.currencyCode ?? 'PHP';
    _category = item?.category ?? 'Entertainment';
    _frequency = item?.frequency ?? BillingFrequency.monthly;
    _nextBillingDate = item?.nextBillingDate ?? DateTime.now();
    _autoRenew = item?.isAutoRenew ?? true;
    _reminderDays = item?.reminderDaysBefore ?? 1;
    _paymentMethodId = item?.paymentMethodId;
    _imagePath = item?.customImagePath;
    _color = item?.fallbackColorHex ?? AppColors.blue.value;
    _iconCode = item?.fallbackIconCode ?? 0;
    _customIntervalController.text =
        item?.customIntervalDays?.toString() ?? '1';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    setState(() => _savingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null)
        throw StateError('The selected image could not be read');
      final decoded = img.decodeImage(bytes);
      if (decoded == null)
        throw const FormatException('Unsupported image file');
      final square = img.copyResizeCropSquare(decoded, size: 256);
      final png = img.encodePng(square);
      final relativePath = 'subscription_icons/${const Uuid().v4()}.png';
      await LocalFileStore.save(relativePath, png);
      if (!mounted) return;
      setState(() => _imagePath = relativePath);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not use this image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }

  int? get _customDays {
    final amount = int.tryParse(_customIntervalController.text);
    if (amount == null || amount < 1) return null;
    return switch (_customUnit) {
      'weeks' => amount * 7,
      'months' => (amount * 30.4375).round(),
      _ => amount,
    };
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    final item = Subscription(
      id: widget.subscription?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      amount: amount,
      currencyCode: _currency,
      frequency: _frequency,
      customIntervalDays: _frequency == BillingFrequency.custom
          ? _customDays
          : null,
      category: _category,
      customImagePath: _imagePath,
      fallbackColorHex: _color,
      fallbackIconCode: _iconCode,
      nextBillingDate: _nextBillingDate,
      isAutoRenew: _autoRenew,
      reminderDaysBefore: _reminderDays,
      paymentMethodId: _paymentMethodId,
      createdAt: widget.subscription?.createdAt ?? DateTime.now(),
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subscription != null;
    final compact = MediaQuery.sizeOf(context).width < 420;
    final amountField = TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Cost'),
      validator: (value) {
        final amount = double.tryParse(value ?? '');
        return amount == null || !amount.isFinite || amount <= 0
            ? 'Enter a positive amount'
            : null;
      },
    );
    final currencyField = DropdownButtonFormField<String>(
      value: _currency,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Currency'),
      items: _currencies
          .map((code) => DropdownMenuItem(value: code, child: Text(code)))
          .toList(),
      onChanged: (value) => setState(() => _currency = value ?? 'PHP'),
    );
    return AlertDialog(
      title: Text(isEditing ? 'Edit subscription' : 'New subscription'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _savingImage ? null : _selectImage,
                      child: FutureBuilder<Uint8List?>(
                        future: _imagePath == null
                            ? Future.value(null)
                            : LocalFileStore.read(_imagePath!),
                        builder: (context, snapshot) {
                          final iconBytes = snapshot.data;
                          return CircleAvatar(
                            radius: 30,
                            backgroundColor: Color(_color).withOpacity(0.25),
                            backgroundImage: iconBytes == null
                                ? null
                                : MemoryImage(iconBytes),
                            child: _savingImage
                                ? const CircularProgressIndicator()
                                : iconBytes == null
                                ? Icon(
                                    fallbackIconFor(_iconCode),
                                    color: Color(_color),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a name'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (compact) ...[
                  amountField,
                  const SizedBox(height: 10),
                  currencyField,
                ] else
                  Row(
                    children: [
                      Expanded(flex: 2, child: amountField),
                      const SizedBox(width: 10),
                      Expanded(child: currencyField),
                    ],
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<BillingFrequency>(
                  value: _frequency,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Billing cycle'),
                  items: _frequencies.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _frequency = value ?? BillingFrequency.monthly,
                  ),
                ),
                if (_frequency == BillingFrequency.custom) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Every'),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _customIntervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                          validator: (_) =>
                              _frequency == BillingFrequency.custom &&
                                  _customDays == null
                              ? 'Use a value above 0'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _customUnit,
                        items: const ['days', 'weeks', 'months']
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _customUnit = value ?? 'days'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'Other'),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Next billing date'),
                  subtitle: Text(
                    '${_nextBillingDate.year}-${_nextBillingDate.month.toString().padLeft(2, '0')}-${_nextBillingDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _nextBillingDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => _nextBillingDate = date);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-renew'),
                  value: _autoRenew,
                  onChanged: (value) => setState(() => _autoRenew = value),
                ),
                DropdownButtonFormField<int>(
                  value: _reminderDays,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Reminder'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Off')),
                    DropdownMenuItem(value: 1, child: Text('1 day before')),
                    DropdownMenuItem(value: 3, child: Text('3 days before')),
                    DropdownMenuItem(value: 7, child: Text('7 days before')),
                  ],
                  onChanged: (value) =>
                      setState(() => _reminderDays = value ?? 0),
                ),
                if (widget.methods.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    value: _paymentMethodId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...widget.methods.map(
                        (method) => DropdownMenuItem<String?>(
                          value: method.id,
                          child: Text(method.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _paymentMethodId = value),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (
                        var index = 0;
                        index < subscriptionFallbackIcons.length;
                        index++
                      )
                        IconButton(
                          tooltip: 'Choose fallback icon',
                          onPressed: () => setState(() => _iconCode = index),
                          icon: Icon(
                            fallbackIconFor(index),
                            color: _iconCode == index
                                ? Color(_color)
                                : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    children: [
                      for (final color in [
                        AppColors.blue,
                        AppColors.green,
                        AppColors.red,
                        AppColors.purple,
                        AppColors.amber,
                        const Color(0xFF64D2FF),
                      ])
                        GestureDetector(
                          onTap: () => setState(() => _color = color.value),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: color,
                            child: _color == color.value
                                ? const Icon(Icons.check, size: 15)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: Text(isEditing ? 'Save' : 'Add')),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'export_file_service.dart';
import 'local_file_store.dart';
import '../../features/subscriptions/data/app_database.dart';
import '../../features/subscriptions/data/subscription_repository.dart';
import '../../features/subscriptions/domain/payment_method_model.dart';
import '../../features/subscriptions/domain/subscription_model.dart';

class BackupExportService {
  BackupExportService(this.database, this.repository);

  final AppDatabase database;
  final SubscriptionRepository repository;

  Future<void> exportBackup() async {
    final subscriptions = await repository.getSubscriptions();
    final methods = await repository.getPaymentMethods();
    final rates = await repository.getExchangeRates();
    final settings = await repository.getSettings();
    final json = utf8.encode(
      jsonEncode({
        'subscriptions': subscriptions.map((e) => e.toMap()).toList(),
        'payment_methods': methods.map((e) => e.toMap()).toList(),
        'exchange_rates': rates,
        'settings': settings,
      }),
    );
    final archive = Archive()
      ..addFile(ArchiveFile('data.json', json.length, json));
    final imagePaths = subscriptions
        .map((item) => item.customImagePath)
        .whereType<String>()
        .toSet();
    for (final relative in imagePaths) {
      final bytes = await LocalFileStore.read(relative);
      if (bytes == null) {
        throw StateError('Subscription icon is missing: $relative');
      }
      archive.addFile(ArchiveFile('icons/$relative', bytes.length, bytes));
    }
    final output = ZipEncoder().encode(archive);
    if (output == null) throw StateError('Could not encode backup archive');
    await saveExportFile(
      fileName: 'subglass-backup.zip',
      extension: 'zip',
      mimeType: 'application/zip',
      bytes: Uint8List.fromList(output),
    );
  }

  Future<void> importBackup() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (selection == null || selection.files.single.bytes == null) return;
    await restoreBackupBytes(selection.files.single.bytes!);
  }

  Future<void> restoreBackupBytes(Uint8List bytes) async {
    final decoded = ZipDecoder().decodeBytes(bytes);
    final dataFile = decoded.findFile('data.json');
    if (dataFile == null)
      throw const FormatException('Backup has no data.json');
    final data =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    final subscriptions = (data['subscriptions'] as List<dynamic>)
        .map(
          (raw) => Subscription.fromMap(Map<String, Object?>.from(raw as Map)),
        )
        .toList();
    final methods = (data['payment_methods'] as List<dynamic>)
        .map(
          (raw) => PaymentMethod.fromMap(Map<String, Object?>.from(raw as Map)),
        )
        .toList();
    final rates = Map<String, dynamic>.from(
      data['exchange_rates'] as Map,
    ).map((key, value) => MapEntry(key, (value as num).toDouble()));
    final settings = Map<String, dynamic>.from(data['settings'] as Map).map((
      key,
      value,
    ) {
      if (value is! String) {
        throw FormatException('Invalid setting value for $key');
      }
      return MapEntry(key, value);
    });
    for (final file in decoded.files.where(
      (f) => f.isFile && f.name.startsWith('icons/'),
    )) {
      final relative = file.name.substring('icons/'.length).split('/');
      if (relative.isEmpty ||
          relative.any((part) => part == '..' || part.isEmpty)) {
        throw const FormatException('Backup contains an invalid icon path');
      }
      await LocalFileStore.save(relative.join('/'), file.content as List<int>);
    }
    await database.transaction(() async {
      await database.execute('DELETE FROM subscriptions');
      await database.execute('DELETE FROM payment_methods');
      await database.execute('DELETE FROM exchange_rates');
      await database.execute('DELETE FROM app_settings');
      for (final item in subscriptions) {
        await repository.saveSubscription(item);
      }
      for (final method in methods) {
        await repository.savePaymentMethod(method);
      }
      await repository.saveExchangeRates(rates);
      for (final entry in settings.entries) {
        await repository.setSetting(entry.key, entry.value);
      }
    });
  }

  Future<void> exportCsv(
    List<Subscription> subscriptions,
    Map<String, double> rates,
    Map<String, String> paymentNames,
  ) async {
    final rows = <List<Object?>>[
      [
        'Name',
        'Amount',
        'Currency',
        'Monthly PHP',
        'Frequency',
        'Category',
        'Payment method',
        'Next billing date',
      ],
      for (final item in subscriptions)
        [
          item.name,
          item.amount,
          item.currencyCode,
          item.monthlyEquivalentInOriginalCurrency *
              (rates[item.currencyCode] ??
                  (item.currencyCode == 'PHP'
                      ? 1
                      : (throw StateError(
                          'No exchange rate available for ${item.currencyCode}',
                        )))),
          item.frequency.name,
          item.category,
          paymentNames[item.paymentMethodId] ?? '',
          item.nextBillingDate.toIso8601String().split('T').first,
        ],
    ];
    final bytes = utf8.encode(const ListToCsvConverter().convert(rows));
    await saveExportFile(
      fileName: 'subglass-subscriptions.csv',
      extension: 'csv',
      mimeType: 'text/csv;charset=utf-8',
      bytes: Uint8List.fromList(bytes),
    );
  }
}

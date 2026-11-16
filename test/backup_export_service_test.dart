import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subglass/core/services/backup_export_service.dart';
import 'package:subglass/features/subscriptions/data/app_database.dart';
import 'package:subglass/features/subscriptions/data/subscription_repository.dart';
import 'package:subglass/features/subscriptions/domain/subscription_model.dart';

void main() {
  test('failed backup restore preserves the existing database', () async {
    final database = AppDatabase(queryExecutor: NativeDatabase.memory());
    final repository = SubscriptionRepository(database);
    final existing = Subscription(
      id: 'existing',
      name: 'Existing subscription',
      amount: 5,
      currencyCode: 'PHP',
      frequency: BillingFrequency.monthly,
      category: 'Other',
      nextBillingDate: DateTime(2026, 1, 1),
      isAutoRenew: true,
      reminderDaysBefore: 1,
      createdAt: DateTime(2025, 1, 1),
    );
    final replacement = Subscription(
      id: 'replacement',
      name: 'Reject this row',
      amount: 10,
      currencyCode: 'PHP',
      frequency: BillingFrequency.monthly,
      category: 'Other',
      nextBillingDate: DateTime(2026, 1, 1),
      isAutoRenew: true,
      reminderDaysBefore: 1,
      createdAt: DateTime(2025, 1, 1),
    );
    final json = utf8.encode(
      jsonEncode({
        'subscriptions': [replacement.toMap()],
        'payment_methods': [],
        'exchange_rates': {'PHP': 1},
        'settings': <String, String>{},
      }),
    );
    final archive = Archive()
      ..addFile(ArchiveFile('data.json', json.length, json));
    final backup = Uint8List.fromList(ZipEncoder().encode(archive)!);

    try {
      await repository.saveSubscription(existing);
      await database.execute('''
        CREATE TRIGGER reject_restore BEFORE INSERT ON subscriptions
        WHEN NEW.name = 'Reject this row'
        BEGIN SELECT RAISE(ABORT, 'test restore failure'); END
      ''');

      await expectLater(
        BackupExportService(database, repository).restoreBackupBytes(backup),
        throwsA(anything),
      );

      expect(
        (await repository.getSubscriptions()).single.toMap(),
        existing.toMap(),
      );
    } finally {
      await database.close();
    }
  });
}

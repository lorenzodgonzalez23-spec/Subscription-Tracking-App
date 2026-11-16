import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/subscriptions/data/app_database.dart';
import 'features/subscriptions/data/subscription_repository.dart';
import 'features/subscriptions/presentation/screens/dashboard_screen.dart';
import 'features/subscriptions/presentation/providers/subscription_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final database = AppDatabase();
  final repository = SubscriptionRepository(database);
  runApp(
    ProviderScope(
      overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
      child: const SubGlassApp(),
    ),
  );
}

class SubGlassApp extends StatelessWidget {
  const SubGlassApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SubGlass',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: const DashboardScreen(),
  );
}

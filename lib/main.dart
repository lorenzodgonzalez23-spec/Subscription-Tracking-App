import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/subscriptions/data/app_database.dart';
import 'features/subscriptions/data/subscription_repository.dart';
import 'features/subscriptions/presentation/screens/dashboard_screen.dart';
import 'features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final preferences = await SharedPreferences.getInstance();
  final appearance = preferences.getString('appearance') ?? 'light';
  AppTheme.themeModeNotifier.value = switch (appearance) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };
  final database = AppDatabase();
  final repository = SubscriptionRepository(database);
  runApp(
    ProviderScope(
      overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
      child: const SubGlassApp(),
    ),
  );
}

class SubGlassApp extends StatefulWidget {
  const SubGlassApp({super.key});

  @override
  State<SubGlassApp> createState() => _SubGlassAppState();
}

class _SubGlassAppState extends State<SubGlassApp> {
  @override
  void initState() {
    super.initState();
    AppTheme.themeModeNotifier.addListener(_themeChanged);
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_themeChanged);
    super.dispose();
  }

  void _themeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Orbit',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: AppTheme.themeModeNotifier.value,
    home: const DashboardScreen(),
  );
}

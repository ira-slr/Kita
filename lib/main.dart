import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/theme.dart';
import 'app/app_shell.dart';
import 'core/database/database_helper.dart';
import 'core/services/notification_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/inventory/add_edit_product_screen.dart';
import 'features/inventory/product_catalog_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/settings_provider.dart';
import 'core/models/product.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (cloud backup / Google Sign-In)
  debugPrint('▶ Initializing Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('✔ Firebase ready.');

  debugPrint('▶ Initializing database...');
  // Initialize database
  await DatabaseHelper().database;
  debugPrint('✔ Database ready.');

  // Initialize local notifications
  await NotificationService.initialize();

  // Check for low-stock items and notify
  NotificationService.checkLowStockAndNotify();

  // Check onboarding status
  debugPrint('▶ Loading preferences...');
  final prefs = await SharedPreferences.getInstance();
  final hasOnboarded = prefs.getBool('has_completed_onboarding') ?? false;
  debugPrint('✔ Preferences loaded. hasOnboarded=$hasOnboarded');

  runApp(
    ProviderScope(
      child: SariSmartApp(hasOnboarded: hasOnboarded),
    ),
  );
}

class SariSmartApp extends ConsumerWidget {
  final bool hasOnboarded;

  const SariSmartApp({super.key, required this.hasOnboarded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'SariSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: hasOnboarded ? '/home' : '/onboarding',
      onGenerateRoute: (routeSettings) {
        switch (routeSettings.name) {
          case '/onboarding':
            return MaterialPageRoute(
              builder: (_) => const OnboardingScreen(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const AppShell(),
            );
          case '/inventory/add':
          case '/inventory/edit':
          case '/inventory/detail':
            final args = routeSettings.arguments;
            final product = args is Product ? args : null;
            return MaterialPageRoute(
              settings: routeSettings,
              builder: (_) =>
                  AddEditProductScreen(existingProduct: product),
            );
          case '/inventory/catalog':
            return MaterialPageRoute(
              builder: (_) => const ProductCatalogScreen(),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Settings')),
                body: const SettingsScreen(),
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const AppShell(),
            );
        }
      },
    );
  }
}

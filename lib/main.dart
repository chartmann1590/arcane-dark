import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'data/local/app_database.dart';
import 'providers/settings_provider.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phase 01 acceptance: Drift DB opens without error (stub)
  await AppDatabase().open();
  // Warm SharedPreferences so first frame has settings
  await SharedPreferences.getInstance();
  final showOnboarding = await shouldShowOnboardingOnLaunch();
  await initializeAds();
  InterstitialAdManager.instance.preload();
  runApp(ProviderScope(child: MyApp(initialLocation: showOnboarding ? '/onboarding' : '/home')));
}

class MyApp extends StatelessWidget {
  final String initialLocation;
  const MyApp({super.key, required this.initialLocation});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Arcane Dark — DnD AI',
      debugShowCheckedModeBanner: false,
      theme: ArcaneTheme.dark,
      routerConfig: buildAppRouter(initialLocation: initialLocation),
    );
  }
}

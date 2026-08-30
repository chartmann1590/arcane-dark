import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'data/local/app_database.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Phase 01 acceptance: Drift DB opens without error (stub)
  await AppDatabase().open();
  // Warm SharedPreferences so first frame has settings
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = await shouldShowOnboardingOnLaunch();
  await initializeAds();
  InterstitialAdManager.instance.preload();
  // Init before the first screen mounts so playMusic() calls in onboarding/router
  // never briefly play at the AudioPlayer's un-configured default volume.
  await AudioService.instance.init(
    musicEnabled: prefs.getBool('musicEnabled') ?? true,
    sfxEnabled: prefs.getBool('sfxEnabled') ?? true,
  );
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

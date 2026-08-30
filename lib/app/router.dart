import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/campaign_hub_screen.dart';
import '../features/character_creation/character_creation_flow.dart';
import '../features/play/game_play_screen.dart';
import '../features/multiplayer/lobby_screen.dart';
import '../features/multiplayer/join_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/privacy_policy_screen.dart';
import '../features/auth/auth_screen.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import 'theme.dart';

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  const ScaffoldWithNav({super.key, required this.child, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    // No banner on the Play tab (index 2) — it must never overlap active
    // narration/gameplay, both for UX and because AdMob policy prohibits
    // placements likely to cause accidental taps over interactive content.
    final showBanner = currentIndex != 2;
    // Dungeon ambience while adventuring, tavern ambience everywhere else in
    // the shell. playMusic() no-ops if this track is already playing, so it's
    // safe to call on every rebuild rather than needing a StatefulWidget.
    AudioService.instance.playMusic(currentIndex == 2 ? MusicTrack.dungeon : MusicTrack.tavern);
    return Scaffold(
      // Each tab's own screen (e.g. GamePlayScreen) has its own nested Scaffold
      // and handles keyboard resizing itself. Letting this outer shell Scaffold
      // resize too double-subtracts the keyboard inset and overflows fixed-height
      // layouts (e.g. Play's map viewport) by the keyboard's height difference.
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ArcaneTheme.border, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBanner) const SafeArea(bottom: false, child: AdBanner()),
            _NavBar(currentIndex: currentIndex),
          ],
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int currentIndex;
  const _NavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            AudioService.instance.playTap();
            switch (i) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/heroes');
                break;
              case 2:
                context.go('/play');
                break;
              case 3:
                context.go('/party');
                break;
              case 4:
                context.go('/settings');
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: ArcaneTheme.background,
          selectedItemColor: ArcaneTheme.primary,
          unselectedItemColor: ArcaneTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Heroes'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Play'),
            BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: 'Party'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        );
  }
}

GoRouter buildAppRouter({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
    GoRoute(path: '/privacy', builder: (c, s) => const PrivacyPolicyScreen()),
    GoRoute(path: '/auth', builder: (c, s) => const AuthScreen()),
    ShellRoute(
      builder: (context, state, child) {
        final loc = state.matchedLocation;
        int idx = 0;
        if (loc.startsWith('/heroes') || loc.startsWith('/create')) idx = 1;
        else if (loc.startsWith('/play')) idx = 2;
        else if (loc.startsWith('/party') || loc.startsWith('/join')) idx = 3;
        else if (loc.startsWith('/settings')) idx = 4;
        else idx = 0;
        return ScaffoldWithNav(currentIndex: idx, child: child);
      },
      routes: [
        GoRoute(path: '/home', builder: (c, s) => const CampaignHubScreen()),
        GoRoute(path: '/heroes', builder: (c, s) => const CharacterCreationFlow()),
        GoRoute(path: '/create', builder: (c, s) => const CharacterCreationFlow()),
        GoRoute(path: '/play', builder: (c, s) => const GamePlayScreen()),
        GoRoute(path: '/party', builder: (c, s) => LobbyScreen(sessionId: s.uri.queryParameters['session'])),
        GoRoute(path: '/join', builder: (c, s) => const JoinScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      ],
    ),
  ],
);

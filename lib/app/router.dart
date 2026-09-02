import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/campaign_hub_screen.dart';
import '../features/heroes/heroes_roster_screen.dart';
import '../features/heroes/character_detail_screen.dart';
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
    // Whenever the keyboard is open, the nav bar + banner strip is hidden
    // entirely rather than just left in place: each tab's nested Scaffold
    // resizes for the keyboard using the full screen height, so if this outer
    // shell kept reserving space for its own bottomNavigationBar, that
    // reserved height would be subtracted a second time — leaving a gap
    // between the keyboard and whatever text field sits above it.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      // Each tab's own screen (e.g. GamePlayScreen) has its own nested Scaffold
      // and handles keyboard resizing itself. Letting this outer shell Scaffold
      // resize too double-subtracts the keyboard inset and overflows fixed-height
      // layouts (e.g. Play's map viewport) by the keyboard's height difference.
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: keyboardOpen
          ? null
          : Container(
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
          items: [
            BottomNavigationBarItem(icon: _NavIcon(Icons.home_rounded, currentIndex == 0), label: 'Home'),
            BottomNavigationBarItem(icon: _NavIcon(Icons.person_rounded, currentIndex == 1), label: 'Heroes'),
            BottomNavigationBarItem(icon: _NavIcon(Icons.explore_rounded, currentIndex == 2), label: 'Play'),
            BottomNavigationBarItem(icon: _NavIcon(Icons.groups_rounded, currentIndex == 3), label: 'Party'),
            BottomNavigationBarItem(icon: _NavIcon(Icons.settings_rounded, currentIndex == 4), label: 'Settings'),
          ],
        );
  }
}

/// A small bounce when a tab becomes selected — makes tab switching feel
/// springy instead of a flat color swap.
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _NavIcon(this.icon, this.selected);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: selected ? 0.85 : 1.0, end: selected ? 1.15 : 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Icon(icon),
    );
  }
}

/// Fade + gentle slide-up transition for screens pushed on top of the shell
/// (character detail, character creation) — the default instant swap felt flat.
CustomTransitionPage<void> _flourishPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 24),
          child: child,
        ),
      );
    },
  );
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
        GoRoute(path: '/heroes', builder: (c, s) => const HeroesRosterScreen()),
        GoRoute(path: '/heroes/:id', pageBuilder: (c, s) => _flourishPage(CharacterDetailScreen(characterId: s.pathParameters['id']!))),
        GoRoute(path: '/create', pageBuilder: (c, s) => _flourishPage(const CharacterCreationFlow())),
        GoRoute(path: '/play', builder: (c, s) => GamePlayScreen(sessionId: s.uri.queryParameters['session'])),
        GoRoute(path: '/party', builder: (c, s) => LobbyScreen(sessionId: s.uri.queryParameters['session'])),
        GoRoute(path: '/join', builder: (c, s) => const JoinScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      ],
    ),
  ],
);

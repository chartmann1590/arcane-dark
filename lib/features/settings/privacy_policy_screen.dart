import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(title: Text('Privacy Policy', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, fontSize: 14))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Arcane Dark Privacy Policy', style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Last updated: August 29, 2026', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          const _Section(
            title: 'The short version',
            body:
                'When you play solo, your story stays on your phone. We never see it, store it, or sell it. '
                'Arcane Dark only talks to the internet for three things: downloading the AI model once, '
                'syncing a multiplayer game you choose to join, and showing ads.',
          ),
          const _Section(
            title: 'Solo play',
            body:
                'Everything about your solo campaigns — your character, your choices, the story the AI tells you — is generated '
                'and stored only on your device. It is never uploaded anywhere. You can play entirely offline (after the '
                'one-time AI model download) and nothing about your adventure ever reaches us or anyone else.',
          ),
          const _Section(
            title: 'Multiplayer play',
            body:
                'If you create or join a multiplayer session, the game state needed to keep everyone in sync — character stats, '
                'party position, quest progress, and the messages you send during that session — is stored in Google Firebase '
                'so other players in your session can see it. This data is tied to an anonymous account, not your name or email '
                '(we never ask for either). It stays only as long as your session, plus a short retention window for troubleshooting.',
          ),
          const _Section(
            title: 'Advertising',
            body:
                'Arcane Dark shows ads through Google AdMob to support development. AdMob may collect device identifiers '
                '(such as your advertising ID) and use them to show ads, including personalized ones, unless you choose otherwise. '
                'If you are in the UK or European Economic Area, you will see a consent screen the first time you open the app, '
                'and you can change your choice anytime from Settings → Privacy Choices. We do not control what AdMob itself '
                'does with this data beyond what Google publishes in its own policies.',
          ),
          const _Section(
            title: 'Crash and performance data',
            body:
                'We use Firebase Crashlytics and Firebase Performance Monitoring to catch bugs and slow spots. These send '
                'technical information — things like device model, OS version, app version, and what screen you were on when '
                'something went wrong — never your campaign text, character names you chose, or anything you typed to the AI.',
          ),
          const _Section(
            title: 'Children',
            body:
                'Arcane Dark is not directed at children under 13, and we do not knowingly collect personal information from '
                'children. Ads shown in this app are not configured for child-directed treatment.',
          ),
          const _Section(
            title: 'Your choices',
            body:
                '• Play solo and offline — nothing leaves your device.\n'
                '• Manage or withdraw ad consent anytime from Settings → Privacy Choices.\n'
                '• Delete a character or campaign anytime from within the app — this removes it from your device immediately.\n'
                '• Uninstalling the app removes all locally stored data, including the downloaded AI model.',
          ),
          const _Section(
            title: 'Third parties this app uses',
            body:
                '• Google Firebase (Authentication, Firestore, Crashlytics, Performance Monitoring)\n'
                '• Google AdMob (advertising)\n'
                '• Hugging Face (one-time download of the open-source Gemma model file)\n'
                'Each of these has its own privacy policy governing how they handle data on their end.',
          ),
          const _Section(
            title: 'Changes to this policy',
            body:
                'If this policy changes in a way that matters, we will update the "Last updated" date above and, for material '
                'changes, note it on the app\'s store listing.',
          ),
          const _Section(
            title: 'Contact',
            body: 'Questions about this policy can be sent to the contact address listed on this app\'s store listing page.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary)),
        const SizedBox(height: 8),
        Text(body, style: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: ArcaneTheme.textSecondary, height: 1.6)),
      ]),
    );
  }
}

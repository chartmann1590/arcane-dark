import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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
          Text('Last updated: September 11, 2026', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          const _Section(
            title: 'The short version',
            body:
                'When you play solo, your story stays on your phone. We never see it, store it, or sell it. '
                'Arcane Dark only talks to the internet for four things: downloading the AI model once, '
                'syncing a multiplayer game you choose to join, showing ads, and transmitting safety reports you submit.',
          ),
          const _Section(
            title: 'Solo play',
            body:
                'Everything about your solo campaigns — your character, your choices, the story the AI tells you — is generated '
                'and stored only on your device. It is never uploaded anywhere. You can play entirely offline (after the '
                'one-time AI model download) and nothing about your adventure ever reaches us or anyone else.',
          ),
          const _Section(
            title: 'Artificial Intelligence & Content Safety',
            body:
                'Arcane Dark uses on-device Generative AI (Google Gemma via LiteRT-LM) to dynamically generate '
                'fantasy roleplaying narratives. In accordance with Google Play Generative AI policies, players can flag '
                'and report inappropriate, offensive, harmful, or policy-violating content using the flag icon on any '
                'scene card or in Settings → AI Safety & Compliance.\n\n'
                'When submitted, reports are sent via encrypted HTTPS to our Cloudflare Worker service and stored in '
                'access-controlled KV storage. They are reviewed strictly by our safety team to enforce guardrails and '
                'prevent harmful output. Reports are never sold or used for advertising.',
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
                '• Report inappropriate AI outputs instantly via the in-app flag icon.\n'
                '• Manage or withdraw ad consent anytime from Settings → Privacy Choices.\n'
                '• Delete a character or campaign anytime from within the app — this removes it from your device immediately.\n'
                '• Uninstalling the app removes all locally stored data, including the downloaded AI model.',
          ),
          const _Section(
            title: 'Account & Data Deletion',
            body:
                'In compliance with Google Play User Data & Account Deletion policies, you can request that your account and all associated cloud data be permanently deleted:\n\n'
                '• In-app: Under Settings → Account, tap "Delete Account" while signed in to instantly erase your authentication record and all synced character rosters from our servers.\n'
                '• Web Portal: Visit our web deletion request page if you have uninstalled the app.\n'
                '• Email: Contact charles.h.hartmann1@gmail.com with subject "Arcane Dark Account and Data Deletion Request". Requests are fulfilled within 48 hours.',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://chartmann1590.github.io/arcane-dark/delete-account.html'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
              label: Text(
                'Open Web Deletion Request Portal',
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFFEF4444)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          const _Section(
            title: 'Third parties this app uses',
            body:
                '• Google Firebase (Authentication, Firestore, Crashlytics, Performance Monitoring)\n'
                '• Google AdMob (advertising)\n'
                '• Cloudflare Workers & KV (secure AI safety reporting & moderation)\n'
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
            body: 'Questions about this policy can be sent to the contact address listed on this app\'s store listing page or to charles.h.hartmann1@gmail.com.',
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

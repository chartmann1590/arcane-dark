import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// Streams the current Firebase user (null until ensureSignedIn() has run at
/// least once). Solo play doesn't depend on this — only multiplayer/cloud
/// sync screens should watch it.
final authStateProvider = StreamProvider<User?>((ref) => AuthService.instance.authStateChanges);

/// True once the user has a real (non-anonymous) identity — Google or email —
/// as opposed to just the anonymous uid created automatically for solo Firestore use.
final hasRealAccountProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user != null && !user.isAnonymous;
});

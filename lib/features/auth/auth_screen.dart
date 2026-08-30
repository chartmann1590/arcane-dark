import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';

/// Only shown when the player opts into something that needs a real identity
/// (multiplayer, cloud sync) — never blocks solo play. Pass [onSignedIn] to
/// pop back to whatever screen asked for sign-in.
class AuthScreen extends StatefulWidget {
  final VoidCallback? onSignedIn;
  const AuthScreen({super.key, this.onSignedIn});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;
  bool _busy = false;
  String? _error;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _done() {
    if (widget.onSignedIn != null) {
      widget.onSignedIn!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) _done();
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.instance.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() => _run(() => AuthService.instance.signInWithGoogle());

  Future<void> _emailSubmit() => _run(() async {
        final email = _emailCtrl.text.trim();
        final password = _passwordCtrl.text;
        if (email.isEmpty || !email.contains('@')) throw AuthException('invalid-email', 'Enter a valid email address.');
        if (password.length < 6) throw AuthException('weak-password', 'Password must be at least 6 characters.');
        if (_isRegister) {
          await AuthService.instance.registerWithEmail(email, password);
        } else {
          await AuthService.instance.signInWithEmail(email, password);
        }
      });

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email above first, then tap "Forgot password?" again.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent to $email', style: GoogleFonts.manrope())));
      }
    } catch (e) {
      setState(() => _error = AuthService.instance.friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(title: Text(_isRegister ? 'CREATE ACCOUNT' : 'SIGN IN', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text('Take your party online', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Sign in to host or join multiplayer sessions and back your characters up to the cloud. Solo play never requires this.', style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _google,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
              label: Text('Continue with Google', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: ArcaneTheme.border)),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Divider(color: ArcaneTheme.border)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted))),
            const Expanded(child: Divider(color: ArcaneTheme.border)),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.manrope(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded, color: ArcaneTheme.textMuted)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            style: GoogleFonts.manrope(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded, color: ArcaneTheme.textMuted)),
            onSubmitted: (_) => _emailSubmit(),
          ),
          if (!_isRegister) ...[
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _busy ? null : _forgotPassword, child: Text('Forgot password?', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)))),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ArcaneTheme.tertiary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: ArcaneTheme.tertiary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.tertiary))),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _emailSubmit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isRegister ? 'Create Account' : 'Sign In', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister ? 'Already have an account? Sign in' : 'New here? Create an account',
                style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

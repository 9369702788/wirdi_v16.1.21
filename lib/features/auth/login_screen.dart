import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

final RegExp _kEmailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+(\.[\w\-]+)*\.[a-zA-Z]{2,}$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;
  @override void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _go(Future<void> Function() fn) async {
    setState(() { _loading = true; _error = null; });
    try { await fn(); if (mounted) Navigator.pushReplacementNamed(context, '/home'); }
    on FirebaseAuthException catch (e) { setState(() { _error = _msg(e.code); }); }
    catch (e) { setState(() { _error = e.toString(); }); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  /// FIX: "Skip for now" used to navigate straight to /home with zero
  /// confirmation or feedback -- users kept mistaking it for a successful
  /// sign-in with whatever they had typed (especially since it sits right
  /// below the Sign In button), reporting it as "any email/password gets
  /// accepted". It never touched Firebase Auth at all; this makes that
  /// explicit and impossible to trigger by accident.
  Future<void> _skip() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.authSkipConfirmTitle),
        content: Text(l.authSkipConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.authSkipConfirmAction)),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  String _msg(String code) {
    const m = {'user-not-found':'No account with this email.','wrong-password':'Incorrect password.','invalid-email':'Invalid email.','too-many-requests':'Too many attempts. Try later.'};
    return m[code] ?? 'Sign-in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryEmerald, Color(0xFF064E3B)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + MediaQuery.of(context).padding.bottom), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 32),
        const Icon(Icons.auto_stories_rounded, size: 64, color: AppColors.goldAccent),
        const SizedBox(height: 12),
        Text(l.appTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(l.authWelcomeBack, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        const SizedBox(height: 36),
        if (_error != null) Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
          child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13))),
        Form(key: _formKey, autovalidateMode: AutovalidateMode.onUserInteraction, child: Column(children: [
          _F(ctrl: _emailCtrl, label: l.authEmail, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => (v==null||!_kEmailRegex.hasMatch(v.trim())) ? l.authInvalidEmail : null),
          const SizedBox(height: 14),
          _F(ctrl: _passCtrl, label: l.authPassword, icon: Icons.lock_outline, obscure: _obscure,
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white70), onPressed: () => setState(() => _obscure = !_obscure)),
            validator: (v) => (v==null||v.length<6) ? l.authPasswordTooShort : null),
          const SizedBox(height: 8),
          Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
            child: Text(l.authForgotPassword, style: const TextStyle(color: AppColors.goldAccent)))),
        ])),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.goldAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _loading ? null : () => _go(() async {
            if (!_formKey.currentState!.validate()) return;
            await AuthService.instance.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
            await SyncService.instance.syncOnSignIn();
          }),
          child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l.authSignIn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        Row(children: [const Expanded(child: Divider(color: Colors.white30)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.authOrContinueWith, style: const TextStyle(color: Colors.white54, fontSize: 12))), const Expanded(child: Divider(color: Colors.white30))]),
        const SizedBox(height: 20),
        _Soc(label: l.authSignInWithGoogle, icon: Icons.g_mobiledata_rounded, onPressed: _loading ? null : () => _go(() async { final c = await AuthService.instance.signInWithGoogle(); if (c==null) throw Exception('cancelled'); await SyncService.instance.syncOnSignIn(); })),
        const SizedBox(height: 12),
        _Soc(label: l.authSignInWithApple, icon: Icons.apple, onPressed: _loading ? null : () => _go(() async { final c = await AuthService.instance.signInWithApple(); if (c==null) throw Exception('cancelled'); await SyncService.instance.syncOnSignIn(); })),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(l.authNoAccount, style: const TextStyle(color: Colors.white70)),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: Text(l.authRegister, style: const TextStyle(color: AppColors.goldAccent, fontWeight: FontWeight.bold))),
        ]),
        TextButton(onPressed: _skip, child: Text(l.authSkipForNow, style: const TextStyle(color: Colors.white38, fontSize: 13))),
      ])))));
  }
}

class _F extends StatelessWidget {
  final TextEditingController ctrl; final String label; final IconData icon;
  final TextInputType? keyboardType; final bool obscure; final Widget? suffixIcon; final String? Function(String?)? validator;
  const _F({required this.ctrl, required this.label, required this.icon, this.keyboardType, this.obscure=false, this.suffixIcon, this.validator});
  @override Widget build(BuildContext context) => TextFormField(controller: ctrl, keyboardType: keyboardType, obscureText: obscure, style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), prefixIcon: Icon(icon, color: Colors.white70), suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white30)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.goldAccent)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      errorStyle: const TextStyle(color: Colors.redAccent)), validator: validator);
}

class _Soc extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback? onPressed;
  const _Soc({required this.label, required this.icon, this.onPressed});
  @override Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    onPressed: onPressed, icon: Icon(icon, size: 22), label: Text(label, style: const TextStyle(fontSize: 15)));
}

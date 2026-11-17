import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import 'wallet_screen.dart';

/// US1.3: sign in with email and password.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.notice});

  /// A message to show on arrival, such as an ended session.
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _error = widget.notice;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final emailError = _email.text.trim().isEmpty
        ? 'Enter your email address.'
        : (looksLikeEmail(_email.text) ? null : 'Enter a valid email address.');
    final passwordError = _password.text.isEmpty
        ? 'Enter your password.'
        : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _error = null;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _loading = true);
    final services = AppServices.of(context);
    final navigator = Navigator.of(context);
    try {
      await services.auth.signIn(
        email: normalizeEmail(_email.text),
        password: _password.text,
      );
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = Messages.forAuthFailure(failure.code);
      });
    }
  }

  void _clearErrors() {
    if (_emailError == null && _passwordError == null && _error == null) return;
    setState(() {
      _emailError = null;
      _passwordError = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to RAAD'),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Container(
                    height: 110,
                    width: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: RaadColors.cyanGlow,
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/raad_logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.bolt_rounded,
                        size: 64,
                        color: RaadColors.cyanAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'R  A  A  D',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: RaadColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Lightning-fast digital transfers',
                    style: TextStyle(
                      fontSize: 13,
                      color: RaadColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              key: const ValueKey('signIn.email'),
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _emailError,
                prefixIcon: const Icon(
                  Icons.alternate_email_rounded,
                  color: RaadColors.textSecondary,
                  size: 20,
                ),
              ),
              onChanged: (_) => _clearErrors(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('signIn.password'),
              controller: _password,
              enabled: !_loading,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _passwordError,
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: RaadColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: RaadColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onChanged: (_) => _clearErrors(),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: RaadColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: RaadColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: RaadColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        key: const ValueKey('signIn.error'),
                        style: const TextStyle(
                          color: RaadColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton(
              key: const ValueKey('signIn.submit'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RaadColors.background,
                      ),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  _email.text = 'sara@raad.test';
                  _password.text = 'Local-preview-1';
                  _clearErrors();
                },
                icon: const Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: RaadColors.cyanAccent,
                ),
                label: const Text(
                  'Quick Fill Demo (Sara)',
                  style: TextStyle(
                    color: RaadColors.cyanAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

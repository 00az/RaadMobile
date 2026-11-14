import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../ui/messages.dart';
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
          padding: const EdgeInsets.all(24),
          children: [
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
              ),
              onChanged: (_) => _clearErrors(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('signIn.password'),
              controller: _password,
              enabled: !_loading,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _passwordError,
              ),
              onChanged: (_) => _clearErrors(),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('signIn.error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('signIn.submit'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

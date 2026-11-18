import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import '../widgets/form_fields.dart';
import '../widgets/status_banner.dart';
import 'confirm_email_screen.dart';

/// S2 (US1.1): display name, email address and password, nothing else
/// (AC1.1.4). The password rule shows before anything is typed (U3); a
/// refusal keeps the email and name (AC1.1.3). The password stays in memory
/// only and is cleared when the screen closes.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _error;
  bool _emailInUse = false;
  bool _busy = false;

  @override
  void dispose() {
    _password.clear();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clear() {
    if (_nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _error == null) {
      return;
    }
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _error = null;
      _emailInUse = false;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final services = AppServices.of(context);
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? l10n.signUpDisplayNameRequired : null;
      _emailError = _email.text.trim().isEmpty
          ? l10n.signInEmailRequired
          : (looksLikeEmail(_email.text) ? null : l10n.signInEmailInvalid);
      _passwordError = meetsPasswordRule(_password.text)
          ? null
          : l10n.passwordRuleBroken;
      _error = null;
      _emailInUse = false;
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }
    if (!services.connectivity.isOnline) {
      setState(() => _error = l10n.offlineBanner);
      return;
    }

    setState(() => _busy = true);
    final email = normalizeEmail(_email.text);
    final navigator = Navigator.of(context);
    try {
      await services.auth.signUp(
        email: email,
        displayName: name,
        password: _password.text,
      );
      _password.clear();
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmEmailScreen(email: email),
        ),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (failure.code) {
          case AuthFailureCode.emailInUse:
            _emailError = l10n.emailInUse;
            _emailInUse = true;
          case AuthFailureCode.passwordRuleFailed:
            _passwordError = l10n.passwordRuleBroken;
          default:
            _error = Messages.forAuthFailure(l10n, failure.code);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signUpTitle),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              const OfflineBanner(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusBanner(
                    kind: StatusKind.error,
                    text: _error!,
                    textKey: const ValueKey('signUp.error'),
                  ),
                ),
              TextField(
                key: const ValueKey('signUp.name'),
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: l10n.signUpDisplayName,
                  errorText: _nameError,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: RaadColors.textSecondary,
                    size: 20,
                  ),
                ),
                onChanged: (_) => _clear(),
              ),
              const SizedBox(height: 16),
              EmailField(
                key: const ValueKey('signUp.email'),
                controller: _email,
                label: l10n.emailLabel,
                errorText: _emailError,
                enabled: !_busy,
                onChanged: (_) => _clear(),
              ),
              if (_emailInUse)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const ValueKey('signUp.signInInstead'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(l10n.signUpSignInInstead),
                  ),
                ),
              const SizedBox(height: 16),
              PasswordField(
                key: const ValueKey('signUp.password'),
                controller: _password,
                label: l10n.passwordLabel,
                errorText: _passwordError,
                helperText: l10n.passwordRule,
                enabled: !_busy,
                newPassword: true,
                onChanged: (_) => _clear(),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.signUpPrivacy,
                style: const TextStyle(
                  color: RaadColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              BusyButton(
                key: const ValueKey('signUp.submit'),
                label: l10n.signUpSubmit,
                busyLabel: l10n.signUpBusy,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

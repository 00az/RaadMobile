import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../ui/messages.dart';
import '../widgets/form_fields.dart';
import '../widgets/status_banner.dart';
import 'reset_password_screen.dart';

/// S4 (US1.5): ask for a reset code. Every answer but a rate limit or a lost
/// connection goes on to S5 with "If an account exists for this address, we
/// sent a code", so the screen never confirms whether an address is
/// registered (C3 check P8).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  String? _emailError;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final services = AppServices.of(context);
    setState(() {
      _emailError = _email.text.trim().isEmpty
          ? l10n.signInEmailRequired
          : (looksLikeEmail(_email.text) ? null : l10n.signInEmailInvalid);
      _error = null;
    });
    if (_emailError != null) return;
    setState(() => _busy = true);
    final email = normalizeEmail(_email.text);
    final navigator = Navigator.of(context);
    try {
      await services.auth.requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() => _busy = false);
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ResetPasswordScreen(email: email),
        ),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = Messages.forAuthFailure(l10n, failure.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.forgotTitle),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const OfflineBanner(),
            Text(l10n.forgotIntro),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StatusBanner(
                  kind: StatusKind.error,
                  text: _error!,
                  textKey: const ValueKey('forgot.error'),
                ),
              ),
            EmailField(
              key: const ValueKey('forgot.email'),
              controller: _email,
              label: l10n.emailLabel,
              errorText: _emailError,
              enabled: !_busy,
              onChanged: (_) => setState(() {
                _emailError = null;
                _error = null;
              }),
            ),
            const SizedBox(height: 24),
            BusyButton(
              key: const ValueKey('forgot.submit'),
              label: l10n.forgotSubmit,
              busyLabel: l10n.forgotBusy,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../ui/messages.dart';
import '../widgets/form_fields.dart';
import '../widgets/status_banner.dart';
import 'sign_in_screen.dart';

/// S5 (US1.5): the emailed code and a new password that follows the rule.
///
/// A wrong or expired code, or a password that breaks the rule, changes
/// nothing and keeps what was typed (AC1.5.2, AC1.5.3). When the answer is
/// lost, the app cannot know whether the password changed, so it does not
/// send the request again: it explains how to go on safely (functional spec,
/// account workflow 4).
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _codeError;
  String? _passwordError;
  String? _error;
  bool _busy = false;
  bool _uncertain = false;

  @override
  void dispose() {
    _password.clear();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _codeError = null;
      _passwordError = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _uncertain) return;
    final l10n = AppLocalizations.of(context);
    final services = AppServices.of(context);
    setState(() {
      _codeError = normalizeCode(_code.text).isEmpty
          ? l10n.confirmCodeRequired
          : null;
      _passwordError = meetsPasswordRule(_password.text)
          ? null
          : l10n.passwordRuleBroken;
      _error = null;
    });
    if (_codeError != null || _passwordError != null) return;
    if (!services.connectivity.isOnline) {
      setState(() => _error = l10n.offlineBanner);
      return;
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await services.auth.confirmPasswordReset(
        email: widget.email,
        code: _code.text,
        newPassword: _password.text,
      );
      _password.clear();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => SignInScreen(
            notice: SignInNotice.passwordChanged,
            email: widget.email,
          ),
        ),
        (_) => false,
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (failure.code) {
          case AuthFailureCode.codeInvalidOrExpired:
            _codeError = l10n.codeInvalid;
          case AuthFailureCode.passwordRuleFailed:
            _passwordError = l10n.passwordRuleBroken;
          case AuthFailureCode.network:
            _uncertain = true;
          default:
            _error = Messages.forAuthFailure(l10n, failure.code);
        }
      });
    }
  }

  void _goToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(email: widget.email),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetTitle),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              const OfflineBanner(),
              StatusBanner(
                kind: StatusKind.info,
                text: l10n.resetCodeSent,
                textKey: const ValueKey('reset.sent'),
              ),
              const SizedBox(height: 16),
              if (_uncertain) ...[
                StatusBanner(
                  kind: StatusKind.warning,
                  text: l10n.resetUncertain,
                  textKey: const ValueKey('reset.uncertain'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('reset.goToSignIn'),
                  onPressed: _goToSignIn,
                  child: Text(l10n.resetGoToSignIn),
                ),
                TextButton(
                  key: const ValueKey('reset.newCode'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.resetNewCode),
                ),
                const SizedBox(height: 16),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusBanner(
                    kind: StatusKind.error,
                    text: _error!,
                    textKey: const ValueKey('reset.error'),
                  ),
                ),
              CodeField(
                key: const ValueKey('reset.code'),
                controller: _code,
                label: l10n.resetCode,
                errorText: _codeError,
                enabled: !_busy && !_uncertain,
                onChanged: (_) => _clear(),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const ValueKey('reset.password'),
                controller: _password,
                label: l10n.resetNewPassword,
                errorText: _passwordError,
                helperText: l10n.passwordRule,
                enabled: !_busy && !_uncertain,
                newPassword: true,
                onChanged: (_) => _clear(),
              ),
              const SizedBox(height: 24),
              BusyButton(
                key: const ValueKey('reset.submit'),
                label: l10n.resetSubmit,
                busyLabel: l10n.resetBusy,
                busy: _busy,
                onPressed: _uncertain ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

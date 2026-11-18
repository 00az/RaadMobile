import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../ui/messages.dart';
import '../widgets/form_fields.dart';
import '../widgets/status_banner.dart';
import 'sign_in_screen.dart';

/// S3 (US1.2; AC1.3.3): confirm an account with the emailed code. Reached
/// after sign-up with the address filled in, or from sign-in for any
/// address.
///
/// **Send the code again** shows "We sent a new code." whatever the address
/// (AC1.2.6, C3 check P7); only a rate limit or a lost connection reads
/// differently. It is off while a request runs.
class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({super.key, this.email = ''});

  final String email;

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  String? _emailError;
  String? _codeError;
  String? _error;
  String? _note;
  bool _confirming = false;
  bool _resending = false;

  bool get _busy => _confirming || _resending;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _emailError = null;
      _codeError = null;
      _error = null;
    });
  }

  String? _checkEmail(AppLocalizations l10n) => _email.text.trim().isEmpty
      ? l10n.signInEmailRequired
      : (looksLikeEmail(_email.text) ? null : l10n.signInEmailInvalid);

  Future<void> _confirm() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final services = AppServices.of(context);
    setState(() {
      _emailError = _checkEmail(l10n);
      _codeError = normalizeCode(_code.text).isEmpty
          ? l10n.confirmCodeRequired
          : null;
      _error = null;
      _note = null;
    });
    if (_emailError != null || _codeError != null) return;

    setState(() => _confirming = true);
    final email = normalizeEmail(_email.text);
    final navigator = Navigator.of(context);
    try {
      await services.auth.confirmSignUp(email: email, code: _code.text);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              SignInScreen(notice: SignInNotice.emailConfirmed, email: email),
        ),
        (_) => false,
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        if (failure.code == AuthFailureCode.codeInvalidOrExpired) {
          _codeError = l10n.codeInvalid;
        } else {
          _error = Messages.forAuthFailure(l10n, failure.code);
        }
      });
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final services = AppServices.of(context);
    setState(() {
      _emailError = _checkEmail(l10n);
      _error = null;
      _note = null;
    });
    if (_emailError != null) return;
    setState(() => _resending = true);
    try {
      await services.auth.resendConfirmationCode(
        email: normalizeEmail(_email.text),
      );
      if (!mounted) return;
      setState(() {
        _resending = false;
        _note = l10n.codeResent;
      });
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = Messages.forAuthFailure(l10n, failure.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.confirmTitle),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const OfflineBanner(),
            Text(l10n.confirmIntro),
            const SizedBox(height: 16),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StatusBanner(
                  kind: StatusKind.info,
                  text: _note!,
                  textKey: const ValueKey('confirm.note'),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StatusBanner(
                  kind: StatusKind.error,
                  text: _error!,
                  textKey: const ValueKey('confirm.error'),
                ),
              ),
            EmailField(
              key: const ValueKey('confirm.email'),
              controller: _email,
              label: l10n.emailLabel,
              errorText: _emailError,
              enabled: !_busy,
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 16),
            CodeField(
              key: const ValueKey('confirm.code'),
              controller: _code,
              label: l10n.confirmCode,
              errorText: _codeError,
              enabled: !_busy,
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 24),
            BusyButton(
              key: const ValueKey('confirm.submit'),
              label: l10n.confirmSubmit,
              busyLabel: l10n.confirmBusy,
              busy: _confirming,
              onPressed: _resending ? null : _confirm,
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('confirm.resend'),
              onPressed: _busy ? null : _resend,
              child: Text(l10n.confirmResend),
            ),
          ],
        ),
      ),
    );
  }
}

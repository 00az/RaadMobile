import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../dev/fake_accounts.dart';
import '../l10n/app_localizations.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import '../widgets/form_fields.dart';
import '../widgets/language_selector.dart';
import '../widgets/status_banner.dart';
import 'confirm_email_screen.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';
import 'wallet_screen.dart';

/// A note shown on arrival at sign-in.
enum SignInNotice {
  sessionEnded,
  signInAgainForSecurity,
  emailConfirmed,
  passwordChanged;

  String text(AppLocalizations l10n) => switch (this) {
    sessionEnded => l10n.signInNoticeSessionEnded,
    signInAgainForSecurity => l10n.signInNoticeIdle,
    emailConfirmed => l10n.signInNoticeEmailConfirmed,
    passwordChanged => l10n.signInNoticePasswordChanged,
  };
}

/// S1 (US1.3, US1.6): sign in with email and password.
///
/// Wrong password, unknown email and unconfirmed account all show the same
/// message (AC1.3.2, AC1.3.3); a rate limit has its own. The way to enter a
/// confirmation code is here for every address, so an unconfirmed account
/// can still be confirmed.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.notice, this.email = ''});

  /// A note to show on arrival, such as an ended session.
  final SignInNotice? notice;

  /// The address to start with, for example after confirming it.
  final String email;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _error;
  late SignInNotice? _notice = widget.notice;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final l10n = AppLocalizations.of(context);
    final emailError = _email.text.trim().isEmpty
        ? l10n.signInEmailRequired
        : (looksLikeEmail(_email.text) ? null : l10n.signInEmailInvalid);
    final passwordError = _password.text.isEmpty
        ? l10n.signInPasswordRequired
        : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _error = null;
      _notice = null;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _loading = true);
    final services = AppServices.of(context);
    final navigator = Navigator.of(context);
    try {
      await services.session.signIn(
        email: normalizeEmail(_email.text),
        password: _password.text,
      );
      _password.clear();
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = Messages.forAuthFailure(l10n, failure.code);
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

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = AppServices.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signInTitle),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              const SizedBox(height: 8),
              const RaadLockup(),
              const SizedBox(height: 8),
              Text(
                l10n.signInTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: RaadColors.textSecondary,
                ),
              ),
              const Center(child: LanguageButton()),
              const SizedBox(height: 16),
              const OfflineBanner(),
              if (_notice case final notice?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusBanner(
                    kind: StatusKind.info,
                    text: notice.text(l10n),
                    textKey: const ValueKey('signIn.notice'),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusBanner(
                    kind: StatusKind.error,
                    text: _error!,
                    textKey: const ValueKey('signIn.error'),
                  ),
                ),
              EmailField(
                key: const ValueKey('signIn.email'),
                controller: _email,
                label: l10n.emailLabel,
                errorText: _emailError,
                enabled: !_loading,
                onChanged: (_) => _clearErrors(),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const ValueKey('signIn.password'),
                controller: _password,
                label: l10n.passwordLabel,
                errorText: _passwordError,
                enabled: !_loading,
                onChanged: (_) => _clearErrors(),
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('signIn.forgot'),
                  onPressed: () => _open(
                    ForgotPasswordScreen(email: normalizeEmail(_email.text)),
                  ),
                  child: Text(l10n.signInForgot),
                ),
              ),
              const SizedBox(height: 8),
              BusyButton(
                key: const ValueKey('signIn.submit'),
                label: l10n.signInSubmit,
                busyLabel: l10n.signInBusy,
                busy: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.signInNewToRaad,
                    style: const TextStyle(color: RaadColors.textSecondary),
                  ),
                  TextButton(
                    key: const ValueKey('signIn.signUp'),
                    onPressed: () => _open(const SignUpScreen()),
                    child: Text(l10n.signInCreateAccount),
                  ),
                ],
              ),
              Center(
                child: TextButton(
                  key: const ValueKey('signIn.haveCode'),
                  onPressed: () => _open(const ConfirmEmailScreen()),
                  child: Text(l10n.signInHaveCode),
                ),
              ),
              if (services.demoShortcuts)
                Center(
                  child: TextButton.icon(
                    key: const ValueKey('signIn.demoFill'),
                    onPressed: () {
                      _email.text = fakeSara.email;
                      _password.text = fakeSara.password;
                      _clearErrors();
                    },
                    icon: const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: RaadColors.cyanAccent,
                    ),
                    label: Text(
                      l10n.signInDemoFill,
                      style: const TextStyle(
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
      ),
    );
  }
}

/// The person's horizontal lockup, the bolt and "رعد RAAD", read as "RAAD".
class RaadLockup extends StatelessWidget {
  const RaadLockup({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: AppLocalizations.of(context).logoLabel,
      child: Center(
        child: Image.asset(
          'assets/images/raad_lockup.webp',
          height: height,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.bolt_rounded,
            size: 64,
            color: RaadColors.cyanAccent,
          ),
        ),
      ),
    );
  }
}

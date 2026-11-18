import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../auth/session_boundary.dart';
import '../l10n/app_localizations.dart';
import '../screens/sign_in_screen.dart';
import '../screens/wallet_screen.dart';
import '../ui/raad_theme.dart';
import 'app_services.dart';
import 'language.dart';

class RaadApp extends StatefulWidget {
  const RaadApp({super.key, required this.services});

  final AppServices services;

  @override
  State<RaadApp> createState() => _RaadAppState();
}

class _RaadAppState extends State<RaadApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  late bool _wasActive = widget.services.session.isActive;

  SessionBoundary get _session => widget.services.session;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    widget.services.language.addListener(_onLanguage);
    widget.services.language.load();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    widget.services.language.removeListener(_onLanguage);
    super.dispose();
  }

  void _onLanguage() => setState(() {});

  /// When an active session ends, every private screen leaves the stack at
  /// once, so neither Back nor reopening shows wallet data (AC1.4.2).
  void _onSession() {
    final active = _session.isActive;
    if (_wasActive && !active) {
      final notice = switch (_session.endReason) {
        SessionEndReason.idle => SignInNotice.signInAgainForSecurity,
        SessionEndReason.expired => SignInNotice.sessionEnded,
        null => null,
      };
      _navigator.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => SignInScreen(notice: notice)),
        (_) => false,
      );
    }
    _wasActive = active;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp(
        navigatorKey: _navigator,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: RaadTheme.darkTheme,
        locale: widget.services.language.locale,
        supportedLocales: LanguageSetting.supportedLocales,
        localizationsDelegates: raadLocalizationsDelegates,
        localeListResolutionCallback: (locales, _) =>
            LanguageSetting.resolve(locales),
        home: const AuthGate(),
      ),
    );
  }
}

/// The localizations every screen needs, in tests as well as in the app.
const List<LocalizationsDelegate<Object>> raadLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Shows the wallet when a stored session may be used, otherwise sign-in.
/// A session idle for more than 30 days ends here (AC1.6.2).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<SessionStatus>? _restoring;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoring ??= AppServices.of(context).session.restore();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppServices.of(context).session;
    return FutureBuilder<SessionStatus>(
      future: _restoring,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return switch (snapshot.data!) {
          SessionStatus.active => const WalletScreen(),
          SessionStatus.ended => SignInScreen(
            notice: session.endReason == SessionEndReason.idle
                ? SignInNotice.signInAgainForSecurity
                : SignInNotice.sessionEnded,
          ),
          SessionStatus.signedOut => const SignInScreen(),
        };
      },
    );
  }
}

/// The DEV or STG chip of C4; production shows none.
class EnvironmentChip extends StatelessWidget {
  const EnvironmentChip({super.key});

  @override
  Widget build(BuildContext context) {
    final label = AppServices.of(context).environmentChip;
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        key: const ValueKey('app.environmentChip'),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

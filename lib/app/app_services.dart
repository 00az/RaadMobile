import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../api/money_service.dart';
import '../auth/auth_service.dart';
import '../auth/session_boundary.dart';
import '../money/balance_snapshot.dart';
import '../money/pending_transfer.dart';
import 'connectivity.dart';
import 'language.dart';
import 'protected_store.dart';

/// The services every screen uses, handed down the widget tree so tests can
/// swap in fakes. [AppServices.create] wires them the same way for the real
/// app, the offline preview, the tests and the integration journeys.
final class AppServices {
  AppServices._({
    required this.auth,
    required this.session,
    required this.money,
    required this.store,
    required this.connectivity,
    required this.pendingTransfers,
    required this.balances,
    required this.language,
    required this.environmentName,
    required this.environmentChip,
    required this.now,
    required this.demoShortcuts,
  });

  factory AppServices.create({
    required AuthService auth,
    required String moneyBaseUrl,
    required String environmentName,
    String? environmentChip,
    HttpClientAdapter? moneyAdapter,
    ProtectedStore? store,
    ConnectivitySignal? connectivity,
    LanguageSetting? language,
    DateTime Function()? now,
    RetryDelay? retryDelay,
    bool demoShortcuts = false,
  }) {
    final clock = now ?? _systemNow;
    final protected = store ?? SecureProtectedStore();
    final pending = PendingTransferStore(protected);
    final balances = BalanceSnapshotStore(protected);
    final session = SessionBoundary(
      auth: auth,
      store: protected,
      now: clock,
      clearAccountData: (accountId) async {
        await pending.clear(owner: accountId, environment: environmentName);
        await balances.clear(owner: accountId, environment: environmentName);
      },
    );
    final money = MoneyService.create(
      baseUrl: moneyBaseUrl,
      auth: session,
      adapter: moneyAdapter,
      retryDelay: retryDelay,
      now: clock,
    );
    return AppServices._(
      auth: auth,
      session: session,
      money: money,
      store: protected,
      connectivity: connectivity ?? PlatformConnectivitySignal(),
      pendingTransfers: pending,
      balances: balances,
      language: language ?? LanguageSetting(protected),
      environmentName: environmentName,
      environmentChip: environmentChip,
      now: clock,
      demoShortcuts: demoShortcuts,
    );
  }

  /// Account actions that need no session: sign-up, confirmation, resend
  /// and password reset. Sign-in and sign-out go through [session].
  final AuthService auth;
  final SessionBoundary session;
  final MoneyService money;
  final ProtectedStore store;
  final ConnectivitySignal connectivity;
  final PendingTransferStore pendingTransfers;
  final BalanceSnapshotStore balances;
  final LanguageSetting language;

  /// `dev`, `stg`, `prd` or `local`; private records are kept per
  /// environment as well as per account.
  final String environmentName;

  /// `DEV`, `STG`, `LOCAL`, or null for production.
  final String? environmentChip;

  final DateTime Function() now;

  /// Fill-in shortcuts for the fake accounts; only the offline preview has
  /// them.
  final bool demoShortcuts;

  static DateTime _systemNow() => DateTime.now();

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!.services;
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

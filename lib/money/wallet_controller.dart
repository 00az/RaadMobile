/// The wallet's balance and set-up state for the signed-in account
/// (US1.2, US2.2, US5.3; BR3.5).
///
/// - A new sign-in runs `PUT /wallet` before the wallet is shown. Failure
///   shows the set-up screen with a safe Try again; the call never credits
///   the opening balance twice.
/// - The last confirmed balance is kept with its UTC time per account and
///   environment. A failed or offline refresh keeps showing it, marked out of
///   date; with nothing kept, the screen shows an error, never a zero.
/// - Only the newest request of the current session may change what is
///   shown: an older answer, or one from a session that has ended, is
///   dropped.
library;

import 'package:flutter/foundation.dart';

import '../api/generated/money_api_client.dart';
import '../api/money_service.dart';
import '../auth/session_boundary.dart';
import 'balance_snapshot.dart';

enum WalletSetup {
  /// `PUT /wallet` is running and nothing is shown yet.
  settingUp,

  /// The wallet exists; the balance views apply.
  ready,

  /// Set-up failed; the person may try again.
  failed,
}

class WalletController extends ChangeNotifier {
  WalletController({
    required this._money,
    required this._session,
    required this._balances,
    required this._environment,
    required this._now,
  });

  final MoneyService _money;
  final SessionBoundary _session;
  final BalanceSnapshotStore _balances;
  final String _environment;
  final DateTime Function() _now;

  WalletSetup _setup = WalletSetup.settingUp;
  BalanceSnapshot? _snapshot;
  bool _stale = false;
  bool _loading = false;
  bool _emailInUse = false;
  MoneyApiException? _error;
  int _generation = 0;
  bool _disposed = false;

  WalletSetup get setup => _setup;

  /// The last balance the Money API confirmed, or null if none is known.
  BalanceSnapshot? get snapshot => _snapshot;

  /// True when [snapshot] is shown because the latest refresh failed.
  bool get isStale => _stale;

  /// A request for the balance is in flight.
  bool get isLoading => _loading;

  /// Set-up failed because the address belongs to another wallet (409).
  bool get emailInUse => _emailInUse;

  /// The failure behind an error or out-of-date view.
  MoneyApiException? get error => _error;

  /// Called once when the wallet opens. With a balance kept from earlier the
  /// wallet already exists, so it refreshes; otherwise it sets the wallet up
  /// first.
  Future<void> start() async {
    final owner = _session.accountId;
    if (owner != null) {
      _snapshot = await _balances.load(owner: owner, environment: _environment);
    }
    if (_disposed) return;
    if (_snapshot != null) {
      _setup = WalletSetup.ready;
      await refresh();
    } else {
      await setUp();
    }
  }

  /// `PUT /wallet`, safe to repeat.
  Future<void> setUp() async {
    final generation = ++_generation;
    final epoch = _session.epoch;
    _setup = WalletSetup.settingUp;
    _emailInUse = false;
    _changed();
    try {
      final balance = await _money.ensureWallet();
      if (!_applies(generation, epoch)) return;
      _setup = WalletSetup.ready;
      await _accept(balance);
    } on MoneyApiException catch (error) {
      if (!_applies(generation, epoch)) return;
      if (error.isAuthenticationRequired) {
        await _session.expire();
        return;
      }
      _setup = WalletSetup.failed;
      _emailInUse = error.status == 409;
      _error = error;
    }
    _changed();
  }

  /// Reads the balance again (Refresh button, pull to refresh, return from
  /// sending). `GET /wallet` never creates a wallet; a missing one is set up.
  Future<void> refresh() async {
    if (_setup != WalletSetup.ready) return setUp();
    final generation = ++_generation;
    final epoch = _session.epoch;
    _loading = true;
    _changed();
    try {
      Money balance;
      try {
        balance = await _money.getBalance();
      } on MoneyApiException catch (error) {
        if (error.code != MoneyErrorCode.walletNotFound) rethrow;
        balance = await _money.ensureWallet();
      }
      if (!_applies(generation, epoch)) return;
      await _accept(balance);
    } on MoneyApiException catch (error) {
      if (!_applies(generation, epoch)) return;
      if (error.isAuthenticationRequired) {
        await _session.expire();
        return;
      }
      _loading = false;
      _stale = _snapshot != null;
      _error = error;
    }
    _changed();
  }

  /// A completed transfer's `balanceAfter` is authoritative too.
  Future<void> acceptBalanceAfterTransfer(int halalas) async {
    ++_generation;
    await _store(BalanceSnapshot(halalas: halalas, updatedAt: _now().toUtc()));
    _changed();
  }

  Future<void> _accept(Money balance) async {
    await _store(
      BalanceSnapshot(
        halalas: balance.amountHalalas,
        updatedAt: _now().toUtc(),
      ),
    );
  }

  Future<void> _store(BalanceSnapshot snapshot) async {
    _snapshot = snapshot;
    _stale = false;
    _loading = false;
    _error = null;
    final owner = _session.accountId;
    if (owner != null) {
      await _balances.save(
        owner: owner,
        environment: _environment,
        snapshot: snapshot,
      );
    }
  }

  bool _applies(int generation, int epoch) =>
      !_disposed && generation == _generation && _session.isCurrent(epoch);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The one place that decides whether private screens may show and requests
/// may carry a token (BR3.1, BR3.2, NFR1.10).
///
/// - Concurrent requests share one token renewal.
/// - The time of last use is kept in protected storage and read from an
///   injected clock. More than 30 days without use (US1.6, C3 check P9: the
///   provider's refresh lifetime is fixed from sign-in, so the idle rule is
///   the app's), or a clock that has gone backwards, ends the session.
/// - When a session ends, its epoch changes, so an answer to a request made
///   in the old session is dropped instead of shown.
/// - Explicit sign-out also removes the account's private data on the phone:
///   the cached balance and the pending transfer. A session that only
///   expired keeps them for the same account to find after signing in again.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/protected_store.dart';
import 'auth_service.dart';

enum SessionStatus { signedOut, active, ended }

/// Why the last session ended without the person signing out.
enum SessionEndReason {
  /// More than 30 days without use, or a clock that went backwards.
  idle,

  /// The token could not be renewed, or the server refused it.
  expired,
}

/// Removes everything the app keeps on the phone for one account.
typedef ClearAccountData = Future<void> Function(String accountId);

final class SessionBoundary extends ChangeNotifier implements TokenSource {
  SessionBoundary({
    required this._auth,
    required this._store,
    required this._now,
    this._clearAccountData,
  });

  static const String lastUseKey = 'raad.session.lastUse';

  /// More idle time than this ends the session.
  static const Duration idleLimit = Duration(days: 30);

  /// A clock this far behind the last recorded use is treated as tampered
  /// with, and the session ends.
  static const Duration clockTolerance = Duration(minutes: 5);

  final AuthService _auth;
  final ProtectedStore _store;
  final DateTime Function() _now;
  final ClearAccountData? _clearAccountData;

  SessionStatus _status = SessionStatus.signedOut;
  SessionEndReason? _endReason;
  String? _accountId;
  int _epoch = 0;
  Future<String?>? _renewal;

  SessionStatus get status => _status;
  SessionEndReason? get endReason => _endReason;

  /// The verified account of the current session.
  String? get accountId => _accountId;

  /// Changes whenever a session starts or ends.
  int get epoch => _epoch;

  bool get isActive => _status == SessionStatus.active;

  /// True while the session that had [epoch] is still the current one.
  bool isCurrent(int epoch) => isActive && epoch == _epoch;

  AuthService get auth => _auth;

  /// Runs [work] and returns its result only if the session that started it
  /// is still current; an answer that arrives after a sign-out, an expiry
  /// or a new sign-in is dropped (null).
  Future<T?> whileCurrent<T>(Future<T> Function() work) async {
    final started = _epoch;
    final result = await work();
    return isCurrent(started) ? result : null;
  }

  /// At app start: picks up a stored session unless it has been idle too
  /// long, in which case it ends it.
  Future<SessionStatus> restore() async {
    if (!await _auth.hasSession()) {
      _status = SessionStatus.signedOut;
      return _status;
    }
    if (await _idleTooLong()) {
      _accountId = await _auth.currentAccountId();
      await _end(SessionEndReason.idle);
      return _status;
    }
    await _start();
    return _status;
  }

  /// Signs in and starts a new session. Throws [AuthFailure].
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signIn(email: email, password: password);
    await _start();
  }

  Future<void> _start() async {
    _accountId = await _auth.currentAccountId();
    _epoch++;
    _status = SessionStatus.active;
    _endReason = null;
    await _touch();
    notifyListeners();
  }

  @override
  Future<String?> accessToken() {
    if (!isActive) return Future.value();
    return _renewal ??= _token().whenComplete(() => _renewal = null);
  }

  Future<String?> _token() async {
    if (await _idleTooLong()) {
      await _end(SessionEndReason.idle);
      return null;
    }
    final epoch = _epoch;
    final token = await _auth.accessToken();
    if (epoch != _epoch) return null;
    if (token == null) {
      await _end(SessionEndReason.expired);
      return null;
    }
    await _touch();
    return token;
  }

  /// The server refused the session (401): end it and ask for sign-in.
  Future<void> expire() => _end(SessionEndReason.expired);

  /// Explicit sign-out (US1.4): ends the session at once, then removes the
  /// tokens, the time of last use and the account's private data.
  Future<void> signOut() async {
    final account = _accountId;
    _epoch++;
    _status = SessionStatus.signedOut;
    _endReason = null;
    _accountId = null;
    notifyListeners();
    await _auth.signOut();
    await _forgetLastUse();
    if (account != null) await _clearAccountData?.call(account);
  }

  Future<void> _end(SessionEndReason reason) async {
    if (_status == SessionStatus.ended) return;
    _epoch++;
    _status = SessionStatus.ended;
    _endReason = reason;
    notifyListeners();
    await _auth.signOut();
    await _forgetLastUse();
  }

  Future<bool> _idleTooLong() async {
    final String? raw;
    try {
      raw = await _store.read(lastUseKey);
    } on Object {
      return true;
    }
    final lastUse = raw == null ? null : DateTime.tryParse(raw);
    // No record of last use: the conservative answer is to sign in again.
    if (lastUse == null) return true;
    final now = _now().toUtc();
    if (now.isBefore(lastUse.subtract(clockTolerance))) return true;
    return now.difference(lastUse) > idleLimit;
  }

  Future<void> _touch() async {
    try {
      await _store.write(lastUseKey, _now().toUtc().toIso8601String());
    } on Object {
      // Without a record the next start asks for sign-in, which is safe.
    }
  }

  Future<void> _forgetLastUse() async {
    try {
      await _store.delete(lastUseKey);
    } on Object {
      // The tokens are gone already; a stale time alone opens nothing.
    }
  }
}

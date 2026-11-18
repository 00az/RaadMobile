// The session boundary: shared renewal, the 30-day idle rule on an injected
// clock, clock anomalies, sign-out clearing and dropped late answers
// (US1.4, US1.6, BR3.2, NFR1.10).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/app/app_services.dart';
import 'package:raad_mobile/app/language.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/auth/session_boundary.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/balance_snapshot.dart';
import 'package:raad_mobile/money/pending_transfer.dart';

import 'support/fakes.dart';

/// An auth service whose token answer the test releases by hand.
final class GatedAuth implements AuthService {
  final FakeAuthService inner = FakeAuthService()..signInAs(fakeSara);
  Completer<String?> gate = Completer<String?>();
  int tokenCalls = 0;

  @override
  Future<String?> accessToken() {
    tokenCalls++;
    return gate.future;
  }

  @override
  Future<String?> currentAccountId() => inner.currentAccountId();
  @override
  Future<bool> hasSession() => inner.hasSession();
  @override
  Future<void> signIn({required String email, required String password}) =>
      inner.signIn(email: email, password: password);
  @override
  Future<void> signOut() => inner.signOut();
  @override
  Future<void> signUp({
    required String email,
    required String displayName,
    required String password,
  }) =>
      inner.signUp(email: email, displayName: displayName, password: password);
  @override
  Future<void> confirmSignUp({required String email, required String code}) =>
      inner.confirmSignUp(email: email, code: code);
  @override
  Future<void> resendConfirmationCode({required String email}) =>
      inner.resendConfirmationCode(email: email);
  @override
  Future<void> requestPasswordReset({required String email}) =>
      inner.requestPasswordReset(email: email);
  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) => inner.confirmPasswordReset(
    email: email,
    code: code,
    newPassword: newPassword,
  );
}

void main() {
  late FakeClock clock;
  late MemoryProtectedStore store;
  late FakeAuthService auth;
  late AppServices services;

  SessionBoundary session() => services.session;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 11, 1, 12));
    store = MemoryProtectedStore();
    auth = FakeAuthService();
    services = AppServices.create(
      auth: auth,
      moneyBaseUrl: FakeMoneyBackend.baseUrl,
      moneyAdapter: FakeMoneyBackend(),
      environmentName: 'dev',
      store: store,
      connectivity: FakeConnectivity(),
      now: clock.call,
    );
  });

  Future<void> signIn() =>
      session().signIn(email: fakeSara.email, password: fakeSara.password);

  test('sign-in starts a session and records the time of last use', () async {
    await signIn();
    expect(session().status, SessionStatus.active);
    expect(session().accountId, fakeSara.sub);
    expect(store.values[SessionBoundary.lastUseKey], clock().toIso8601String());
  });

  test('concurrent requests share one token renewal', () async {
    final gated = GatedAuth();
    final boundary = SessionBoundary(
      auth: gated,
      store: store,
      now: clock.call,
    );
    store.values[SessionBoundary.lastUseKey] = clock().toIso8601String();
    await boundary.restore();

    final answers = Future.wait([
      boundary.accessToken(),
      boundary.accessToken(),
      boundary.accessToken(),
    ]);
    await pumpEventQueue();
    gated.gate.complete('renewed-token');
    expect(await answers, ['renewed-token', 'renewed-token', 'renewed-token']);
    expect(gated.tokenCalls, 1);

    gated.gate = Completer<String?>()..complete('next');
    expect(await boundary.accessToken(), 'next');
    expect(gated.tokenCalls, 2, reason: 'a later request renews again');
  });

  test('renews without sign-in 61 minutes later (test clock)', () async {
    await signIn();
    clock.advance(const Duration(minutes: 61));
    expect(await session().accessToken(), fakeSara.token);
    expect(session().status, SessionStatus.active);
  });

  test('30 days without use still opens the wallet', () async {
    await signIn();
    clock.advance(const Duration(days: 30));
    expect(await session().restore(), SessionStatus.active);
  });

  test('31 days without use asks for sign-in again (AC1.6.2)', () async {
    await signIn();
    clock.advance(const Duration(days: 31));
    expect(await session().restore(), SessionStatus.ended);
    expect(session().endReason, SessionEndReason.idle);
    expect(await auth.hasSession(), isFalse, reason: 'tokens are removed');
    expect(store.values.containsKey(SessionBoundary.lastUseKey), isFalse);
  });

  test(
    'a request after 31 idle days ends the session and sends no token',
    () async {
      await signIn();
      clock.advance(const Duration(days: 31, minutes: 1));
      expect(await session().accessToken(), isNull);
      expect(session().status, SessionStatus.ended);
    },
  );

  test('each use moves the idle window on', () async {
    await signIn();
    clock.advance(const Duration(days: 20));
    expect(await session().accessToken(), isNotNull);
    clock.advance(const Duration(days: 20));
    expect(await session().restore(), SessionStatus.active);
  });

  test('a clock that went backwards ends the session', () async {
    await signIn();
    clock.advance(const Duration(hours: -2));
    expect(await session().restore(), SessionStatus.ended);
    expect(session().endReason, SessionEndReason.idle);
  });

  test(
    'a stored session with no record of last use asks for sign-in',
    () async {
      auth.signInAs(fakeSara);
      expect(await session().restore(), SessionStatus.ended);
    },
  );

  test('a refused renewal ends the session but keeps the account data for '
      'the same person to find', () async {
    await signIn();
    await services.pendingTransfers.save(
      PendingTransfer(
        requestKey: '0b6a5d2e-0000-4000-8000-0000000000aa',
        owner: fakeSara.sub,
        environment: 'dev',
        recipientEmail: 'omar@raad.test',
        recipientName: 'Omar Saleh',
        recipientDisplayEmail: 'omar@raad.test',
        amountHalalas: 100,
        balanceBeforeHalalas: 100000,
        createdAt: clock(),
        status: PendingStatus.uncertain,
      ),
    );
    var heard = 0;
    session().addListener(() => heard++);
    auth.expireSession = true;

    expect(await session().accessToken(), isNull);
    expect(session().status, SessionStatus.ended);
    expect(session().endReason, SessionEndReason.expired);
    expect(heard, 1);
    expect(
      await services.pendingTransfers.load(
        owner: fakeSara.sub,
        environment: 'dev',
      ),
      isNotNull,
    );
  });

  test('sign-out removes tokens, last use, the cached balance and the '
      'pending transfer', () async {
    await signIn();
    await services.balances.save(
      owner: fakeSara.sub,
      environment: 'dev',
      snapshot: BalanceSnapshot(halalas: 4200, updatedAt: clock()),
    );
    await services.pendingTransfers.save(
      PendingTransfer(
        requestKey: '0b6a5d2e-0000-4000-8000-0000000000bb',
        owner: fakeSara.sub,
        environment: 'dev',
        recipientEmail: 'omar@raad.test',
        recipientName: 'Omar Saleh',
        recipientDisplayEmail: 'omar@raad.test',
        amountHalalas: 100,
        balanceBeforeHalalas: 100000,
        createdAt: clock(),
        status: PendingStatus.uncertain,
      ),
    );
    await services.language.choose(AppLanguage.ar);
    final epoch = session().epoch;

    await session().signOut();

    expect(session().status, SessionStatus.signedOut);
    expect(session().accountId, isNull);
    expect(session().epoch, isNot(epoch));
    expect(await auth.hasSession(), isFalse);
    expect(store.values.keys, [
      LanguageSetting.storageKey,
    ], reason: 'only the installation language is left');
    expect(await session().accessToken(), isNull);
  });

  test('an answer that arrives after sign-out is dropped', () async {
    await signIn();
    final answer = Completer<int>();
    final late = session().whileCurrent(() => answer.future);
    await session().signOut();
    answer.complete(4200);
    expect(await late, isNull);
  });

  test('an answer from an earlier session is dropped even after signing in '
      'again', () async {
    await signIn();
    final answer = Completer<String>();
    final late = session().whileCurrent(() => answer.future);
    await session().signOut();
    await signIn();
    answer.complete('old balance');
    expect(await late, isNull);
    expect(await session().whileCurrent(() async => 'fresh'), 'fresh');
  });

  test('the server refusing the session ends it', () async {
    await signIn();
    await session().expire();
    expect(session().status, SessionStatus.ended);
    expect(session().endReason, SessionEndReason.expired);
    expect(await auth.hasSession(), isFalse);
  });
}

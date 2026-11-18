import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/balance_snapshot.dart';

import 'support/harness.dart';

Future<Harness> openWallet(WidgetTester tester, [Harness? given]) async {
  final harness = given ?? (Harness()..signedInAsSara());
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('first load opens the wallet with PUT and shows 1,000.00 SAR', (
    tester,
  ) async {
    final harness = await openWallet(tester);

    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
    expect(harness.backend.countOf('PUT /wallet'), 1);
    expect(harness.backend.countOf('GET /wallet'), 0);
    expect(harness.backend.countOf('GET /transfers'), 1);
    expect(harness.backend.requests.every((r) => r.hasBearer), isTrue);
    expect(byKey('history.empty'), findsOneWidget);
    expect(byKey('wallet.stale'), findsNothing);
  });

  testWidgets('an existing wallet keeps its balance (200 from PUT)', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.openWallet(fakeSara, balanceHalalas: 2500050);
    await openWallet(tester, harness);

    expect(textOf(tester, 'wallet.balance'), '25,000.50 SAR');
  });

  testWidgets('refresh reads with GET and sets up again on WALLET_NOT_FOUND', (
    tester,
  ) async {
    final harness = await openWallet(tester);
    harness.backend.forgetWallet(fakeSara);

    await tapKey(tester, 'wallet.refresh');

    expect(harness.backend.countOf('GET /wallet'), 1);
    expect(harness.backend.countOf('PUT /wallet'), 2);
    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
  });

  testWidgets('a read is retried once after a timeout', (tester) async {
    final harness = await openWallet(tester);
    harness.backend.setBalance(fakeSara, 77700);
    harness.backend.failNext('GET /wallet', FakeFault.timeout);

    await tapKey(tester, 'wallet.refresh');

    expect(harness.backend.countOf('GET /wallet'), 2);
    expect(textOf(tester, 'wallet.balance'), '777.00 SAR');
  });

  testWidgets('a failed refresh keeps the balance, marked out of date with '
      'its time, and keeps the history (AC2.2.1)', (tester) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.seedTransfer(
      sender: fakeOmar,
      recipient: fakeSara,
      amountHalalas: 2500,
      completedAt: DateTime.utc(2026, 11, 10, 9),
    );
    await openWallet(tester, harness);
    final loadedAt = DateFormat('HH:mm').format(harness.clock().toLocal());
    harness.clock.advance(const Duration(minutes: 7));
    harness.backend.failNext('GET /wallet', FakeFault.unavailable, times: 2);

    await tapKey(tester, 'wallet.refresh');

    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
    expect(textOf(tester, 'wallet.stale'), en.walletBalanceStale(loadedAt));
    expect(find.text(en.historyReceivedFrom('Omar Saleh')), findsOneWidget);
  });

  testWidgets('a good refresh removes the out-of-date mark (AC2.2.3)', (
    tester,
  ) async {
    final harness = await openWallet(tester);
    // A lost connection is not retried; only timeouts, 500 and 503 are.
    harness.backend.failNext('GET /wallet', FakeFault.connectionLost);
    await tapKey(tester, 'wallet.refresh');
    expect(byKey('wallet.stale'), findsOneWidget);
    expect(harness.backend.countOf('GET /wallet'), 1);

    harness.backend.setBalance(fakeSara, 120000);
    await tapKey(tester, 'wallet.staleRetry');

    expect(byKey('wallet.stale'), findsNothing);
    expect(byKey('wallet.updated'), findsOneWidget);
    expect(textOf(tester, 'wallet.balance'), '1,200.00 SAR');
  });

  testWidgets('a restart without a connection shows the kept balance as out '
      'of date, not a zero', (tester) async {
    final harness = Harness()..signedInAsSara();
    await harness.services.balances.save(
      owner: fakeSara.sub,
      environment: 'dev',
      snapshot: BalanceSnapshot(
        halalas: 4321,
        updatedAt: DateTime.utc(2026, 11, 16, 20, 5),
      ),
    );
    harness.backend.failNext('GET /wallet', FakeFault.connectionLost, times: 2);
    harness.backend.failNext(
      'GET /transfers',
      FakeFault.connectionLost,
      times: 2,
    );
    await openWallet(tester, harness);

    expect(textOf(tester, 'wallet.balance'), '43.21 SAR');
    expect(byKey('wallet.stale'), findsOneWidget);
    expect(harness.backend.countOf('PUT /wallet'), 0);
  });

  testWidgets('pull to refresh reads the balance and history again', (
    tester,
  ) async {
    final harness = await openWallet(tester);
    harness.backend.setBalance(fakeSara, 150000);

    await tester.fling(
      byKey('wallet.pullToRefresh'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(harness.backend.countOf('GET /wallet'), 1);
    expect(harness.backend.countOf('GET /transfers'), 2);
    expect(textOf(tester, 'wallet.balance'), '1,500.00 SAR');
  });

  testWidgets('hiding the balance shows dots and keeps the amount private', (
    tester,
  ) async {
    await openWallet(tester);
    await tapKey(tester, 'wallet.toggleBalance');
    expect(textOf(tester, 'wallet.balance'), '••••••');
    await tapKey(tester, 'wallet.toggleBalance');
    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
  });

  testWidgets('an ended session returns to sign-in with a notice', (
    tester,
  ) async {
    final harness = await openWallet(tester);
    final before = harness.backend.requests.length;
    harness.auth.expireSession = true;

    await tapKey(tester, 'wallet.refresh');

    expect(byKey('signIn.submit'), findsOneWidget);
    expect(textOf(tester, 'signIn.notice'), en.signInNoticeSessionEnded);
    expect(harness.backend.requests.length, before);
  });

  testWidgets('sign out removes the session and shows sign-in', (tester) async {
    final harness = await openWallet(tester);

    await tapKey(tester, 'wallet.signOut');

    expect(byKey('signIn.submit'), findsOneWidget);
    expect(byKey('signIn.notice'), findsNothing);
    expect(await harness.auth.hasSession(), isFalse);
  });
}

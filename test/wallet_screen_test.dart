import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/ui/messages.dart';

import 'support/harness.dart';

void main() {
  testWidgets('first load opens the wallet with PUT and shows 1,000.00 SAR', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
    expect(harness.backend.countOf('PUT /wallet'), 1);
    expect(harness.backend.countOf('GET /wallet'), 0);
    expect(harness.backend.countOf('GET /transfers'), 1);
    expect(harness.backend.requests.every((r) => r.hasBearer), isTrue);
    expect(byKey('history.empty'), findsOneWidget);
  });

  testWidgets('an existing wallet keeps its balance (200 from PUT)', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.openWallet(fakeSara, balanceHalalas: 2500050);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(textOf(tester, 'wallet.balance'), '25,000.50 SAR');
  });

  testWidgets('a failed setup offers Retry, and Retry opens the wallet', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.failNext('PUT /wallet', FakeFault.unavailable);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(textOf(tester, 'walletSetup.error'), Messages.walletSetupFailed);
    expect(byKey('wallet.balance'), findsNothing);

    await tapKey(tester, 'walletSetup.retry');

    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
    expect(harness.backend.countOf('PUT /wallet'), 2);
  });

  testWidgets('refresh reads with GET and sets up again on WALLET_NOT_FOUND', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    harness.backend.forgetWallet(fakeSara);

    await tapKey(tester, 'wallet.refresh');

    expect(harness.backend.countOf('GET /wallet'), 1);
    expect(harness.backend.countOf('PUT /wallet'), 2);
    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
  });

  testWidgets('a read is retried once after a timeout', (tester) async {
    final harness = Harness()..signedInAsSara();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    harness.backend.setBalance(fakeSara, 77700);
    harness.backend.failNext('GET /wallet', FakeFault.timeout);

    await tapKey(tester, 'wallet.refresh');

    expect(harness.backend.countOf('GET /wallet'), 2);
    expect(textOf(tester, 'wallet.balance'), '777.00 SAR');
  });

  testWidgets('a balance error does not hide the history', (tester) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.seedTransfer(
      sender: fakeOmar,
      recipient: fakeSara,
      amountHalalas: 2500,
      completedAt: DateTime.utc(2026, 11, 10, 9),
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    harness.backend.failNext('GET /wallet', FakeFault.unavailable);

    await tapKey(tester, 'wallet.refresh');

    expect(textOf(tester, 'wallet.balanceError'), Messages.generic);
    expect(find.text('From Omar Saleh'), findsOneWidget);
  });

  testWidgets('an ended session returns to sign-in with a notice', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final before = harness.backend.requests.length;
    harness.auth.expireSession = true;

    await tapKey(tester, 'wallet.refresh');

    expect(byKey('signIn.submit'), findsOneWidget);
    expect(textOf(tester, 'signIn.error'), Messages.sessionExpired);
    expect(harness.backend.requests.length, before);
  });

  testWidgets('sign out removes the session and shows sign-in', (tester) async {
    final harness = Harness()..signedInAsSara();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tapKey(tester, 'wallet.signOut');

    expect(byKey('signIn.submit'), findsOneWidget);
    expect(byKey('signIn.error'), findsNothing);
    expect(await harness.auth.hasSession(), isFalse);
  });
}

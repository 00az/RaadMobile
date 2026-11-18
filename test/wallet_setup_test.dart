// Wallet set-up after sign-in (US1.2: AC1.2.3 to AC1.2.5; BR3.1): nothing
// private shows until `PUT /wallet` succeeds, a failure offers a safe Try
// again, and repeating it never credits the opening balance twice.

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';

import 'support/harness.dart';

const putWallet = 'PUT /wallet';

void main() {
  testWidgets('nothing private shows until set-up succeeds', (tester) async {
    final harness = Harness()..signedInAsSara();
    final setUp = harness.backend.hold(putWallet);
    await tester.pumpWidget(harness.app());
    await tester.pump();
    await tester.pump();

    expect(byKey('walletSetup.loading'), findsOneWidget);
    expect(find.text(en.walletSettingUp), findsOneWidget);
    expect(byKey('wallet.balance'), findsNothing);
    expect(byKey('wallet.send'), findsNothing);

    setUp.complete();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
  });

  testWidgets('a failed set-up offers Try again, which opens one wallet', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    // The first attempt and its one permitted retry both fail.
    harness.backend.failNext(putWallet, FakeFault.unavailable, times: 2);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.text(en.walletSetupFailedTitle), findsOneWidget);
    expect(textOf(tester, 'walletSetup.error'), en.walletSetupFailedBody);
    expect(byKey('wallet.balance'), findsNothing);
    expect(find.textContaining('0.00'), findsNothing, reason: 'no zero');

    await tapKey(tester, 'walletSetup.retry');

    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
    expect(harness.backend.countOf(putWallet), 3);
    expect(harness.backend.balanceOf(fakeSara), 100000);
  });

  testWidgets('setting up again never credits the opening balance twice', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    // A second phone, or a retried first sign-in, runs set-up again.
    await tester.runAsync(() async {
      await harness.money.ensureWallet();
      await harness.money.ensureWallet();
    });

    await tapKey(tester, 'wallet.refresh');
    expect(harness.backend.balanceOf(fakeSara), 100000);
    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
  });

  testWidgets('an address held by another wallet says so', (tester) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.answerNext(putWallet, 409, 'VALIDATION_ERROR');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(textOf(tester, 'walletSetup.error'), en.walletSetupEmailInUse);
  });

  testWidgets('a person can sign out from the set-up screen', (tester) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.failNext(putWallet, FakeFault.unavailable, times: 2);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tapKey(tester, 'walletSetup.signOut');

    expect(byKey('signIn.submit'), findsOneWidget);
    expect(await harness.auth.hasSession(), isFalse);
  });

  testWidgets('a refused token during set-up asks for sign-in', (tester) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.answerNext(putWallet, 401, 'AUTHENTICATION_REQUIRED');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(byKey('signIn.submit'), findsOneWidget);
    expect(textOf(tester, 'signIn.notice'), en.signInNoticeSessionEnded);
  });
}

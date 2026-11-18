// Offline rules (US3.9, US2.2; BR3.5, NFR9.10): without a connection Send,
// Continue, Confirm and Try again are off with a stated reason, come back
// when it returns, and nothing is ever queued or sent by itself. The signal
// is only advisory: a transfer that fails in transport while "online" still
// ends in the uncertain state.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';

import 'support/harness.dart';

const transfers = 'POST /transfers';

Future<Harness> openWallet(WidgetTester tester) async {
  final harness = Harness()..signedInAsSara();
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
  return harness;
}

bool enabled(WidgetTester tester, String key) {
  final widget = tester.widget(byKey(key));
  return switch (widget) {
    final ButtonStyleButton button => button.onPressed != null,
    final InkWell ink => ink.onTap != null,
    _ => throw StateError('$key is not a button'),
  };
}

void main() {
  testWidgets('the wallet turns Send off with a reason, and back on', (
    tester,
  ) async {
    final harness = await openWallet(tester);

    harness.connectivity.online = false;
    await tester.pump();
    expect(enabled(tester, 'wallet.send'), isFalse);
    expect(textOf(tester, 'wallet.sendOffline'), en.walletSendOffline);

    harness.connectivity.online = true;
    await tester.pump();
    expect(enabled(tester, 'wallet.send'), isTrue);
    expect(byKey('wallet.sendOffline'), findsNothing);
  });

  testWidgets('the form turns Continue off and on without leaving the '
      'screen (AC3.9.1, AC3.9.2)', (tester) async {
    final harness = await openWallet(tester);
    await fillSendForm(tester, email: fakeOmar.email, amount: '100');

    harness.connectivity.online = false;
    await tester.pump();
    expect(enabled(tester, 'send.continue'), isFalse);
    expect(textOf(tester, 'send.offline'), en.sendingNeedsConnection);
    await tester.tap(byKey('send.continue'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(harness.backend.countOf('POST /recipients/resolve'), 0);

    harness.connectivity.online = true;
    await tester.pump();
    expect(enabled(tester, 'send.continue'), isTrue);
    expect(find.text('100'), findsOneWidget, reason: 'the draft stays');
  });

  testWidgets('review turns Confirm off while offline; nothing is queued', (
    tester,
  ) async {
    final harness = await openWallet(tester);
    await fillSendForm(tester, email: fakeOmar.email, amount: '100');
    await tapKey(tester, 'send.continue');

    harness.connectivity.online = false;
    await tester.pump();
    expect(enabled(tester, 'review.confirm'), isFalse);
    expect(textOf(tester, 'review.offline'), en.sendingNeedsConnection);

    harness.connectivity.online = true;
    await tester.pumpAndSettle();
    expect(enabled(tester, 'review.confirm'), isTrue);
    expect(harness.backend.countOf(transfers), 0, reason: 'nothing queued');
  });

  testWidgets('Try again is off while offline and never fires by itself', (
    tester,
  ) async {
    final harness = await openWallet(tester);
    await fillSendForm(tester, email: fakeOmar.email, amount: '100');
    await tapKey(tester, 'send.continue');
    harness.backend.failNext(transfers, FakeFault.connectionLost);
    await tapKey(tester, 'review.confirm');
    expect(byKey('review.outcomeUnknown'), findsOneWidget);

    harness.connectivity.online = false;
    await tester.pump();
    expect(enabled(tester, 'review.tryAgain'), isFalse);

    harness.connectivity.online = true;
    await tester.pumpAndSettle();
    expect(enabled(tester, 'review.tryAgain'), isTrue);
    expect(harness.backend.countOf(transfers), 1, reason: 'no automatic send');
  });

  testWidgets('a transport failure while "online" ends uncertain, not '
      'refused', (tester) async {
    final harness = await openWallet(tester);
    await fillSendForm(tester, email: fakeOmar.email, amount: '100');
    await tapKey(tester, 'send.continue');
    harness.backend.failNext(transfers, FakeFault.connectionLost);

    await tapKey(tester, 'review.confirm');

    expect(byKey('review.outcomeUnknown'), findsOneWidget);
    expect(find.text(en.transferUnconfirmedBody), findsOneWidget);
  });

  testWidgets('a refresh while offline keeps the balance, marked out of date', (
    tester,
  ) async {
    final harness = await openWallet(tester);
    harness.connectivity.online = false;
    harness.backend.failNext('GET /wallet', FakeFault.connectionLost);

    await tapKey(tester, 'wallet.refresh');

    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
    expect(byKey('wallet.stale'), findsOneWidget);
  });
}

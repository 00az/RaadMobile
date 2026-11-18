// The send flow over the generated client and the U2 contract fake: form,
// review, confirm, result, the uncertain view with same-key Try again,
// Change details, and an intent restored after a restart (US3.1 to US3.8,
// BR3.3, BR3.4).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/pending_transfer.dart';

import 'support/harness.dart';

const transfers = 'POST /transfers';
const resolves = 'POST /recipients/resolve';

Future<Harness> openWallet(WidgetTester tester, [Harness? given]) async {
  final harness = given ?? (Harness()..signedInAsSara());
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
  return harness;
}

/// Fills the form, resolves Omar and stops on the review screen.
Future<Harness> reviewHundredToOmar(WidgetTester tester) async {
  final harness = await openWallet(tester);
  await fillSendForm(tester, email: ' Omar@RAAD.test ', amount: '100');
  await tapKey(tester, 'send.continue');
  expect(byKey('review.confirm'), findsOneWidget);
  return harness;
}

List<String?> keysSent(Harness harness) => [
  for (final r in harness.backend.requests)
    if (r.operation == transfers) r.idempotencyKey,
];

void main() {
  group('Send form', () {
    testWidgets('checks the email and amount before any request', (
      tester,
    ) async {
      final harness = await openWallet(tester);
      await tapKey(tester, 'wallet.send');

      await tapKey(tester, 'send.continue');
      expect(find.text(en.sendEmailRequired), findsOneWidget);
      expect(find.text(en.sendAmountRequired), findsOneWidget);

      await enter(tester, 'send.email', 'omar@raad');
      for (final (amount, message) in [
        ('abc', en.sendAmountInvalid),
        ('1.234', en.amountRange),
        ('0', en.amountRange),
        ('-5', en.amountRange),
        ('0.99', en.amountRange),
        ('500.01', en.amountRange),
      ]) {
        await enter(tester, 'send.amount', amount);
        await tapKey(tester, 'send.continue');
        expect(find.text(en.sendEmailInvalid), findsOneWidget);
        expect(find.text(message), findsOneWidget, reason: amount);
      }
      expect(harness.backend.countOf(resolves), 0);
    });

    testWidgets('refuses more than the balance without a request', (
      tester,
    ) async {
      final harness = Harness()..signedInAsSara();
      harness.backend.openWallet(fakeSara, balanceHalalas: 30000);
      await openWallet(tester, harness);
      await fillSendForm(tester, email: fakeOmar.email, amount: '300.01');
      await tapKey(tester, 'send.continue');

      expect(find.text(en.balanceLow), findsOneWidget);
      expect(harness.backend.countOf(resolves), 0);
    });

    testWidgets('"Max" fills the most one transfer may send, from integers', (
      tester,
    ) async {
      await openWallet(tester);
      await tapKey(tester, 'wallet.send');
      await tapKey(tester, 'send.max');
      expect(find.text('500.00'), findsOneWidget);
      await tapKey(tester, 'send.quick.5000');
      expect(find.text('50.00'), findsOneWidget);
    });

    testWidgets('says no RAAD user has the address and keeps the values', (
      tester,
    ) async {
      final harness = await openWallet(tester);
      await fillSendForm(tester, email: 'nobody@raad.test', amount: '25.50');
      await tapKey(tester, 'send.continue');

      expect(find.text(en.noSuchUser), findsOneWidget);
      expect(find.text('nobody@raad.test'), findsOneWidget);
      expect(find.text('25.50'), findsOneWidget);
      expect(harness.backend.countOf(transfers), 0);
    });

    testWidgets('refuses sending to your own wallet', (tester) async {
      await openWallet(tester);
      await fillSendForm(tester, email: fakeSara.email, amount: '10');
      await tapKey(tester, 'send.continue');

      expect(find.text(en.ownAddress), findsOneWidget);
    });

    testWidgets('the demo fill-in exists only in the offline preview', (
      tester,
    ) async {
      await openWallet(tester);
      await tapKey(tester, 'wallet.send');
      expect(byKey('send.demoFill'), findsNothing);
    });
  });

  group('Review', () {
    testWidgets('shows recipient, email, amount and balance after', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);

      expect(textOf(tester, 'review.name'), 'Omar Saleh');
      expect(textOf(tester, 'review.email'), 'omar@raad.test');
      expect(textOf(tester, 'review.amount'), '100.00 SAR');
      expect(textOf(tester, 'review.projectedBalance'), '900.00 SAR');
      final lookup = harness.backend.requests.last;
      expect(lookup.operation, resolves);
      expect(lookup.body, {'email': 'omar@raad.test'});
    });

    testWidgets('cancel sends nothing and returns to the filled form', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);

      await tapKey(tester, 'review.cancel');

      expect(harness.backend.countOf(transfers), 0);
      expect(find.text('100'), findsOneWidget);
      expect(harness.backend.balanceOf(fakeSara), 100000);
      expect(
        await harness.services.pendingTransfers.load(
          owner: fakeSara.sub,
          environment: 'dev',
        ),
        isNull,
      );
    });
  });

  group('Confirm', () {
    testWidgets('sends integer halalas with a key and shows the result', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);

      await tapKey(tester, 'review.confirm');

      final sent = harness.backend.requests.lastWhere(
        (r) => r.operation == transfers,
      );
      expect(sent.body, {
        'recipientEmail': 'omar@raad.test',
        'amountHalalas': 10000,
      });
      expect(sent.hasBearer, isTrue);
      expect(
        sent.idempotencyKey,
        matches(RegExp(r'^[A-Za-z0-9._~-]{16,128}$')),
      );
      expect(textOf(tester, 'result.reference'), 'R-222222222223');
      expect(textOf(tester, 'result.balance'), '900.00 SAR');
      expect(
        textOf(tester, 'result.summary'),
        en.resultSummary('100.00 SAR', 'Omar Saleh'),
      );

      await tapKey(tester, 'result.done');

      expect(textOf(tester, 'wallet.balance'), '900.00 SAR');
      expect(find.textContaining('Omar Saleh'), findsWidgets);
      expect(harness.backend.balanceOf(fakeOmar), 110000);
      expect(byKey('wallet.pending'), findsNothing);
    });

    testWidgets('a second tap while sending sends nothing more', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      final gate = Completer<void>();
      harness.backend.transferGate = gate;

      await tester.tap(byKey('review.confirm'));
      await tester.pump();
      expect(find.text(en.reviewSending), findsOneWidget);
      await tester.tap(byKey('review.confirm'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.backend.countOf(transfers), 1);
      expect(harness.backend.balanceOf(fakeSara), 90000);
      expect(byKey('result.reference'), findsOneWidget);
    });

    testWidgets('a low-balance refusal returns to the form with its values', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.setBalance(fakeSara, 5000);

      await tapKey(tester, 'review.confirm');

      expect(find.text(en.balanceLow), findsOneWidget);
      expect(find.text(' Omar@RAAD.test '), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('a refused attempt and the next one use different keys', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.setBalance(fakeSara, 5000);
      await tapKey(tester, 'review.confirm');
      harness.backend.setBalance(fakeSara, 100000);

      await tapKey(tester, 'send.continue');
      await tapKey(tester, 'review.confirm');

      expect(byKey('result.reference'), findsOneWidget);
      expect(keysSent(harness).toSet(), hasLength(2));
    });

    testWidgets('an amount the service puts outside the range is explained', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.answerNext(transfers, 422, 'AMOUNT_OUT_OF_RANGE');

      await tapKey(tester, 'review.confirm');

      expect(find.text(en.amountRange), findsOneWidget);
      expect(harness.backend.balanceOf(fakeSara), 100000);
    });

    testWidgets(
      'a missing wallet is set up, then confirmed with the same key',
      (tester) async {
        final harness = await reviewHundredToOmar(tester);
        harness.backend.forgetWallet(fakeSara);

        await tapKey(tester, 'review.confirm');
        expect(textOf(tester, 'review.notice'), en.reviewWalletReady);

        await tapKey(tester, 'review.confirm');

        expect(keysSent(harness), hasLength(2));
        expect(keysSent(harness).toSet(), hasLength(1));
        expect(byKey('result.reference'), findsOneWidget);
      },
    );

    testWidgets('an ended session stops the transfer before it is sent', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      harness.auth.expireSession = true;

      await tapKey(tester, 'review.confirm');

      expect(byKey('signIn.submit'), findsOneWidget);
      expect(harness.backend.countOf(transfers), 0);
    });
  });

  group('Unknown outcome', () {
    for (final fault in [
      FakeFault.timeout,
      FakeFault.connectionLost,
      FakeFault.serverError,
      FakeFault.unavailable,
      FakeFault.undeclaredStatus,
    ]) {
      testWidgets('after ${fault.name} nothing is sent again by itself', (
        tester,
      ) async {
        final harness = await reviewHundredToOmar(tester);
        harness.backend.failNext(transfers, fault);

        await tapKey(tester, 'review.confirm');

        expect(byKey('review.outcomeUnknown'), findsOneWidget);
        expect(byKey('review.confirm'), findsNothing);
        expect(byKey('review.tryAgain'), findsOneWidget);
        await tester.pump(const Duration(minutes: 1));
        expect(harness.backend.countOf(transfers), 1);
      });
    }

    testWidgets('Try again sends the same key and details, and the money '
        'moves once (AC3.8.2)', (tester) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);
      await tapKey(tester, 'review.confirm');
      expect(harness.backend.balanceOf(fakeSara), 90000, reason: 'committed');

      await tapKey(tester, 'review.tryAgain');

      expect(textOf(tester, 'result.reference'), 'R-222222222223');
      expect(textOf(tester, 'result.balance'), '900.00 SAR');
      expect(keysSent(harness), hasLength(2));
      expect(keysSent(harness).toSet(), hasLength(1));
      expect(harness.backend.transfersBetween(fakeSara, fakeOmar), 1);
      expect(harness.backend.balanceOf(fakeSara), 90000);
    });

    testWidgets('a rate limit on Try again shows the wait and keeps the '
        'intent', (tester) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.failNext(transfers, FakeFault.timeout);
      await tapKey(tester, 'review.confirm');
      harness.backend.answerNext(
        transfers,
        429,
        'RATE_LIMITED',
        retryAfterSeconds: 30,
      );

      await tapKey(tester, 'review.tryAgain');

      expect(textOf(tester, 'review.notice'), en.tooManyAttemptsSeconds(30));
      expect(byKey('review.outcomeUnknown'), findsOneWidget);
      expect(
        await harness.services.pendingTransfers.load(
          owner: fakeSara.sub,
          environment: 'dev',
        ),
        isNotNull,
      );
    });

    testWidgets('a lost answer is reconciled from balance and history, and '
        'the wallet keeps the intent open', (tester) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);

      await tapKey(tester, 'review.confirm');
      expect(byKey('review.outcomeUnknown'), findsOneWidget);

      await tapKey(tester, 'review.checkWallet');

      expect(harness.backend.countOf(transfers), 1);
      expect(textOf(tester, 'wallet.balance'), '900.00 SAR');
      expect(find.textContaining('Omar Saleh'), findsWidgets);
      expect(byKey('wallet.pending'), findsOneWidget);
    });

    testWidgets('Change details drops the key and asks to check the history '
        'first', (tester) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.failNext(transfers, FakeFault.timeout);
      await tapKey(tester, 'review.confirm');
      final oldKey = keysSent(harness).single;

      await tapKey(tester, 'review.changeDetails');

      expect(byKey('send.checkHistoryFirst'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      await tapKey(tester, 'send.continue');
      await tapKey(tester, 'review.confirm');
      expect(byKey('result.reference'), findsOneWidget);
      expect(keysSent(harness).last, isNot(oldKey));
    });

    testWidgets('system Back after a lost answer goes to the wallet, never '
        'back to a form that could send again', (tester) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);

      await tapKey(tester, 'review.confirm');
      expect(byKey('review.outcomeUnknown'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(byKey('review.confirm'), findsNothing);
      expect(byKey('send.continue'), findsNothing);
      expect(textOf(tester, 'wallet.balance'), '900.00 SAR');
      expect(harness.backend.countOf(transfers), 1);
    });

    testWidgets('system Back while a transfer is sending does nothing', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      final gate = Completer<void>();
      harness.backend.transferGate = gate;

      await tester.tap(byKey('review.confirm'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(byKey('review.confirm'), findsOneWidget);
      expect(byKey('send.continue'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(harness.backend.countOf(transfers), 1);
    });
  });

  group('After a restart', () {
    PendingTransfer pendingFor(FakeAccount owner) => PendingTransfer(
      requestKey: '0b6a5d2e-0000-4000-8000-0000000000cc',
      owner: owner.sub,
      environment: 'dev',
      recipientEmail: 'omar@raad.test',
      recipientName: 'Omar Saleh',
      recipientDisplayEmail: 'omar@raad.test',
      amountHalalas: 2500,
      balanceBeforeHalalas: 100000,
      createdAt: DateTime.utc(2026, 11, 17, 8),
      status: PendingStatus.uncertain,
    );

    testWidgets('an unresolved intent is shown, and sent only by Try again', (
      tester,
    ) async {
      final harness = Harness()..signedInAsSara();
      await harness.services.pendingTransfers.save(pendingFor(fakeSara));
      await openWallet(tester, harness);

      expect(byKey('wallet.pending'), findsOneWidget);
      await tapKey(tester, 'wallet.pendingReview');
      expect(byKey('review.outcomeUnknown'), findsOneWidget);
      expect(textOf(tester, 'review.amount'), '25.00 SAR');
      expect(harness.backend.countOf(transfers), 0);

      await tapKey(tester, 'review.tryAgain');
      expect(byKey('result.reference'), findsOneWidget);
      expect(keysSent(harness), ['0b6a5d2e-0000-4000-8000-0000000000cc']);

      await tapKey(tester, 'result.done');
      expect(byKey('wallet.pending'), findsNothing);
      expect(textOf(tester, 'wallet.balance'), '975.00 SAR');
    });

    testWidgets('Change details on a restored intent opens the form with its '
        'values and a new key', (tester) async {
      final harness = Harness()..signedInAsSara();
      await harness.services.pendingTransfers.save(pendingFor(fakeSara));
      await openWallet(tester, harness);
      await tapKey(tester, 'wallet.pendingReview');

      await tapKey(tester, 'review.changeDetails');

      await showKey(tester, 'send.checkHistoryFirst');
      expect(byKey('send.checkHistoryFirst'), findsOneWidget);
      expect(find.text('omar@raad.test'), findsOneWidget);
      expect(find.text('25.00'), findsOneWidget);
      expect(harness.backend.countOf(transfers), 0);
    });

    testWidgets('another account never sees the intent', (tester) async {
      final harness = Harness()..signedInAsSara();
      await harness.services.pendingTransfers.save(pendingFor(fakeOmar));
      await openWallet(tester, harness);

      expect(byKey('wallet.pending'), findsNothing);
    });
  });
}

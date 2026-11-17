import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/ui/messages.dart';

import 'support/harness.dart';

const transfers = 'POST /transfers';
const resolves = 'POST /recipients/resolve';

Future<Harness> openWallet(WidgetTester tester) async {
  final harness = Harness()..signedInAsSara();
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

void main() {
  group('Send form', () {
    testWidgets('checks the email and amount before any request', (
      tester,
    ) async {
      final harness = await openWallet(tester);
      await tapKey(tester, 'wallet.send');

      await tapKey(tester, 'send.continue');
      expect(find.text("Enter the recipient's email address."), findsOneWidget);
      expect(find.text('Enter an amount.'), findsOneWidget);

      for (final amount in ['abc', '1.234', '0', '-5']) {
        await enter(tester, 'send.email', 'omar@raad');
        await enter(tester, 'send.amount', amount);
        await tapKey(tester, 'send.continue');
        expect(find.text('Enter a complete email address.'), findsOneWidget);
        expect(
          find.text('Enter an amount in SAR with up to two decimals.'),
          findsOneWidget,
        );
      }
      expect(harness.backend.countOf(resolves), 0);
    });

    testWidgets('refuses more than the balance without a request', (
      tester,
    ) async {
      final harness = await openWallet(tester);
      await fillSendForm(tester, email: fakeOmar.email, amount: '1000.01');
      await tapKey(tester, 'send.continue');

      expect(find.text(Messages.insufficientFunds), findsOneWidget);
      expect(harness.backend.countOf(resolves), 0);
    });

    testWidgets('says no RAAD user has the address and keeps the values', (
      tester,
    ) async {
      final harness = await openWallet(tester);
      await fillSendForm(tester, email: 'nobody@raad.test', amount: '25.50');
      await tapKey(tester, 'send.continue');

      expect(textOf(tester, 'send.error'), Messages.recipientNotFound);
      expect(find.text('nobody@raad.test'), findsOneWidget);
      expect(find.text('25.50'), findsOneWidget);
      expect(harness.backend.countOf(transfers), 0);
    });

    testWidgets('refuses sending to your own wallet', (tester) async {
      await openWallet(tester);
      await fillSendForm(tester, email: fakeSara.email, amount: '10');
      await tapKey(tester, 'send.continue');

      expect(textOf(tester, 'send.error'), Messages.selfTransfer);
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
      expect(textOf(tester, 'result.reference'), 'RD-000001');
      expect(textOf(tester, 'result.balance'), '900.00 SAR');
      expect(
        textOf(tester, 'result.summary'),
        'You sent 100.00 SAR to Omar Saleh.',
      );

      await tapKey(tester, 'result.done');

      expect(textOf(tester, 'wallet.balance'), '900.00 SAR');
      expect(find.text('To Omar Saleh'), findsOneWidget);
      expect(harness.backend.balanceOf(fakeOmar), 110000);
    });

    testWidgets('a second tap while sending sends nothing more', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      final gate = Completer<void>();
      harness.backend.transferGate = gate;

      await tester.tap(byKey('review.confirm'));
      await tester.pump();
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

      expect(textOf(tester, 'send.error'), Messages.insufficientFunds);
      expect(find.text('omar@raad.test'), findsNothing);
      expect(find.text(' Omar@RAAD.test '), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('U1 sends any positive amount, even below 1 SAR', (
      tester,
    ) async {
      final harness = await openWallet(tester);
      await fillSendForm(tester, email: fakeOmar.email, amount: '0.50');
      await tapKey(tester, 'send.continue');
      await tapKey(tester, 'review.confirm');

      expect(textOf(tester, 'result.balance'), '999.50 SAR');
      expect(harness.backend.balanceOf(fakeOmar), 100050);
    });

    testWidgets('an amount outside the allowed range is explained (U2)', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.answerNext(transfers, 422, 'AMOUNT_OUT_OF_RANGE');

      await tapKey(tester, 'review.confirm');

      expect(textOf(tester, 'send.error'), Messages.amountOutOfRange);
      expect(harness.backend.balanceOf(fakeSara), 100000);
    });

    testWidgets(
      'a missing wallet is set up, then confirmed with the same key',
      (tester) async {
        final harness = await reviewHundredToOmar(tester);
        harness.backend.forgetWallet(fakeSara);

        await tapKey(tester, 'review.confirm');
        expect(
          textOf(tester, 'review.notice'),
          Messages.walletReadyConfirmAgain,
        );

        await tapKey(tester, 'review.confirm');

        final keys = harness.backend.requests
            .where((r) => r.operation == transfers)
            .map((r) => r.idempotencyKey)
            .toList();
        expect(keys, hasLength(2));
        expect(keys.toSet(), hasLength(1));
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
      FakeFault.serverError,
      FakeFault.unavailable,
      FakeFault.undeclaredStatus,
    ]) {
      testWidgets('after ${fault.name} it blocks a resend', (tester) async {
        final harness = await reviewHundredToOmar(tester);
        harness.backend.failNext(transfers, fault);

        await tapKey(tester, 'review.confirm');

        expect(byKey('review.outcomeUnknown'), findsOneWidget);
        expect(byKey('review.confirm'), findsNothing);
        expect(harness.backend.countOf(transfers), 1);
      });
    }

    testWidgets('a lost answer is reconciled from balance and history', (
      tester,
    ) async {
      final harness = await reviewHundredToOmar(tester);
      harness.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);

      await tapKey(tester, 'review.confirm');
      expect(byKey('review.outcomeUnknown'), findsOneWidget);

      await tapKey(tester, 'review.checkWallet');

      expect(harness.backend.countOf(transfers), 1);
      expect(textOf(tester, 'wallet.balance'), '900.00 SAR');
      expect(find.text('To Omar Saleh'), findsOneWidget);
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
}

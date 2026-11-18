// Every refusal on the way to sending shows its own message and keeps what
// the person typed (US3.3 to US3.5; AC3.3.4, AC3.4.3; FR3.12).

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/l10n/app_localizations.dart';

import 'support/harness.dart';

const transfers = 'POST /transfers';
const resolves = 'POST /recipients/resolve';

/// One way a send can be refused.
final class Refusal {
  const Refusal(
    this.name, {
    required this.email,
    required this.amount,
    required this.message,
    this.setUp,
    this.atConfirm = false,
  });

  final String name;
  final String email;
  final String amount;
  final String Function(AppLocalizations l10n) message;
  final void Function(Harness harness)? setUp;

  /// Refused when Confirm is pressed rather than at Continue.
  final bool atConfirm;
}

final refusals = [
  Refusal(
    'unknown recipient',
    email: 'Nobody@Raad.test',
    amount: '25',
    message: (l) => l.noSuchUser,
  ),
  Refusal(
    'own wallet',
    email: ' SARA@raad.test',
    amount: '25',
    message: (l) => l.ownAddress,
  ),
  Refusal(
    'too low',
    email: 'omar@raad.test',
    amount: '0.99',
    message: (l) => l.amountRange,
  ),
  Refusal(
    'too high',
    email: 'omar@raad.test',
    amount: '500.01',
    message: (l) => l.amountRange,
  ),
  Refusal(
    'balance too low',
    email: 'omar@raad.test',
    amount: '400',
    message: (l) => l.balanceLow,
    setUp: (h) => h.backend.openWallet(fakeSara, balanceHalalas: 30000),
  ),
  Refusal(
    'lookups rate limited',
    email: 'omar@raad.test',
    amount: '25',
    message: (l) => l.tooManyAttemptsSeconds(20),
    setUp: (h) => h.backend.answerNext(
      resolves,
      429,
      'RATE_LIMITED',
      retryAfterSeconds: 20,
    ),
  ),
  Refusal(
    'the service finds the balance too low',
    email: 'omar@raad.test',
    amount: '25',
    message: (l) => l.balanceLow,
    setUp: (h) => h.backend.answerNext(transfers, 422, 'INSUFFICIENT_FUNDS'),
    atConfirm: true,
  ),
  Refusal(
    'the service refuses the recipient',
    email: 'omar@raad.test',
    amount: '25',
    message: (l) => l.noSuchUser,
    setUp: (h) => h.backend.answerNext(transfers, 404, 'RECIPIENT_NOT_FOUND'),
    atConfirm: true,
  ),
  Refusal(
    'transfers rate limited',
    email: 'omar@raad.test',
    amount: '25',
    message: (l) => l.tooManyAttemptsSeconds(45),
    setUp: (h) => h.backend.answerNext(
      transfers,
      429,
      'RATE_LIMITED',
      retryAfterSeconds: 45,
    ),
    atConfirm: true,
  ),
  Refusal(
    'blocked at the edge',
    email: 'omar@raad.test',
    amount: '25',
    message: (l) => l.requestBlocked,
    setUp: (h) => h.backend.answerNext(transfers, 403, 'FORBIDDEN'),
    atConfirm: true,
  ),
  Refusal(
    'an error code this version does not know',
    email: 'omar@raad.test',
    amount: '25',
    message: (l) => l.genericError,
    setUp: (h) => h.backend.answerNext(resolves, 409, 'WALLET_FROZEN'),
  ),
];

void main() {
  for (final refusal in refusals) {
    testWidgets('${refusal.name}: its message, with the values kept', (
      tester,
    ) async {
      final harness = Harness()..signedInAsSara();
      refusal.setUp?.call(harness);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await fillSendForm(tester, email: refusal.email, amount: refusal.amount);
      await tapKey(tester, 'send.continue');
      if (refusal.atConfirm) await tapKey(tester, 'review.confirm');

      expect(find.text(refusal.message(en)), findsOneWidget);
      expect(find.text(refusal.email), findsOneWidget);
      expect(find.text(refusal.amount), findsOneWidget);
      expect(byKey('send.continue'), findsOneWidget);
      expect(harness.backend.balanceOf(fakeSara), isNot(lessThan(30000)));
      expect(
        await harness.services.pendingTransfers.load(
          owner: fakeSara.sub,
          environment: 'dev',
        ),
        isNull,
        reason: 'a settled refusal leaves no open intent',
      );
    });
  }
}

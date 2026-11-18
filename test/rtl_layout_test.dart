// Arabic and English on screen (US5.1; AC5.1.1 to AC5.1.4; BR3.7): Arabic is
// right to left, emails, references and amounts stay isolated left-to-right
// units with Western digits, and switching language changes text and
// direction at once without signing out, losing a draft or changing a
// transfer's key.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/app/language.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/ui/formatting.dart';

import 'support/display.dart';
import 'support/harness.dart';

const transfers = 'POST /transfers';
final String isolate = String.fromCharCode(0x2066);
final String popIsolate = String.fromCharCode(0x2069);

Future<Harness> openWalletIn(WidgetTester tester, AppLanguage? language) async {
  final harness = Harness()..signedInAsSara();
  if (language != null) await harness.language.choose(language);
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
  return harness;
}

TextDirection directionAt(WidgetTester tester, String key) =>
    Directionality.of(tester.element(byKey(key)));

String fieldText(WidgetTester tester, String key) => tester
    .widget<TextField>(
      find.descendant(
        of: byKey(key),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    )
    .controller!
    .text;

void main() {
  testWidgets('Arabic lays the wallet out right to left in Arabic', (
    tester,
  ) async {
    await openWalletIn(tester, AppLanguage.ar);

    expect(directionAt(tester, 'wallet.balance'), TextDirection.rtl);
    expect(find.text(ar.walletTitle), findsOneWidget);
    expect(find.text(ar.walletAvailableBalance), findsOneWidget);
    expect(find.text(en.walletTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English lays the wallet out left to right', (tester) async {
    await openWalletIn(tester, AppLanguage.en);
    expect(directionAt(tester, 'wallet.balance'), TextDirection.ltr);
    expect(find.text(en.walletTitle), findsOneWidget);
  });

  testWidgets('an Arabic amount is the figure then ر.س, as one isolated '
      'unit with Western digits (A8)', (tester) async {
    await openWalletIn(tester, AppLanguage.ar);
    final shown = textOf(tester, 'wallet.balance');
    expect(shown, '${isolate}1,000.00 ر.س$popIsolate');
    expect(withoutDirectionMarks(shown), '1,000.00 ر.س');
    expect(RegExp('[٠-٩]').hasMatch(shown), isFalse);
  });

  testWidgets('emails, amounts and references stay left to right inside '
      'Arabic screens', (tester) async {
    await openWalletIn(tester, AppLanguage.ar);
    await fillSendForm(tester, email: fakeOmar.email, amount: '100');
    final emailField = tester.widget<TextField>(
      find.descendant(
        of: byKey('send.email'),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    );
    expect(emailField.textDirection, TextDirection.ltr);
    await tapKey(tester, 'send.continue');

    expect(
      textOf(tester, 'review.email'),
      '${isolate}omar@raad.test$popIsolate',
    );
    expect(
      withoutDirectionMarks(textOf(tester, 'review.amount')),
      '100.00 ر.س',
    );
    await tapKey(tester, 'review.confirm');
    expect(
      textOf(tester, 'result.reference'),
      '${isolate}R-222222222223$popIsolate',
    );
    expect(find.text(ar.resultTitle), findsOneWidget);
  });

  testWidgets('before a choice the app follows an Arabic phone', (
    tester,
  ) async {
    usePhoneLocale(tester, const Locale('ar', 'SA'));
    await openWalletIn(tester, null);
    expect(find.text(ar.walletTitle), findsOneWidget);
  });

  testWidgets('a phone in another language gets English', (tester) async {
    usePhoneLocale(tester, const Locale('fr'));
    await openWalletIn(tester, null);
    expect(find.text(en.walletTitle), findsOneWidget);
  });

  testWidgets('the sign-in language button switches at once', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.text(en.signInSubmit), findsWidgets);

    await tapKey(tester, 'app.language');

    expect(find.text(ar.signInSubmit), findsWidgets);
    expect(directionAt(tester, 'signIn.submit'), TextDirection.rtl);
    expect(harness.language.chosen, AppLanguage.ar);
  });

  testWidgets('switching language mid-draft keeps every typed value and the '
      'session', (tester) async {
    final harness = await openWalletIn(tester, AppLanguage.en);
    await fillSendForm(tester, email: ' Omar@RAAD.test ', amount: '12.50');

    await harness.language.choose(AppLanguage.ar);
    await tester.pumpAndSettle();

    expect(find.text(ar.sendTitle), findsOneWidget);
    expect(directionAt(tester, 'send.continue'), TextDirection.rtl);
    expect(fieldText(tester, 'send.email'), ' Omar@RAAD.test ');
    expect(fieldText(tester, 'send.amount'), '12.50');
    expect(harness.session.isActive, isTrue);
  });

  testWidgets('switching language mid-uncertain keeps the intent and its key', (
    tester,
  ) async {
    final harness = await openWalletIn(tester, AppLanguage.en);
    await fillSendForm(tester, email: fakeOmar.email, amount: '100');
    await tapKey(tester, 'send.continue');
    harness.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);
    await tapKey(tester, 'review.confirm');

    await harness.language.choose(AppLanguage.ar);
    await tester.pumpAndSettle();
    expect(find.text(ar.transferUnconfirmedTitle), findsOneWidget);
    expect(harness.backend.countOf(transfers), 1, reason: 'nothing resent');

    await tapKey(tester, 'review.tryAgain');
    final keys = harness.backend.requests
        .where((r) => r.operation == transfers)
        .map((r) => r.idempotencyKey)
        .toSet();
    expect(keys, hasLength(1));
    expect(harness.backend.balanceOf(fakeSara), 90000);
  });

  testWidgets('the account screen switches language without signing in '
      'again (AC5.1.3)', (tester) async {
    final harness = await openWalletIn(tester, AppLanguage.en);
    final epoch = harness.session.epoch;
    await tapKey(tester, 'wallet.account');

    await tapKey(tester, 'language.ar');

    expect(find.text(ar.accountTitle), findsOneWidget);
    expect(harness.session.epoch, epoch);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(ar.walletTitle), findsOneWidget);
    expect(byKey('wallet.balance'), findsOneWidget);
  });

  testWidgets('the account screens render in Arabic without overflow', (
    tester,
  ) async {
    final harness = Harness();
    await harness.language.choose(AppLanguage.ar);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    for (final link in ['signIn.signUp', 'signIn.haveCode', 'signIn.forgot']) {
      await tapKey(tester, link);
      expect(tester.takeException(), isNull, reason: link);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(find.text(ar.signInTitle), findsWidgets);
  });
}

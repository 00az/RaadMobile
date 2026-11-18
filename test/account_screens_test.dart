// Account screens over the fake C3 sign-in: sign-up, confirmation and
// resend, the confirmation link on sign-in, forgot and reset password,
// sign-out and the session-ended screens (US1.1 to US1.6; BR3.1).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';

import 'support/harness.dart';

Future<Harness> openSignIn(WidgetTester tester, [Harness? given]) async {
  final harness = given ?? Harness();
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
  return harness;
}

bool buttonEnabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(byKey(key)).onPressed != null;

Future<void> signUp(
  WidgetTester tester, {
  String name = 'Amal',
  String email = ' Amal@Example.test ',
  String password = 'Abcdef12',
}) async {
  await tapKey(tester, 'signIn.signUp');
  await enter(tester, 'signUp.name', name);
  await enter(tester, 'signUp.email', email);
  await enter(tester, 'signUp.password', password);
  await tapKey(tester, 'signUp.submit');
}

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
  group('Sign-up (S2)', () {
    testWidgets('shows the password rule before anything is typed', (
      tester,
    ) async {
      await openSignIn(tester);
      await tapKey(tester, 'signIn.signUp');
      expect(find.text(en.passwordRule), findsOneWidget);
      expect(find.text(en.signUpPrivacy), findsOneWidget);
    });

    testWidgets('a sign-up opens confirmation with the address filled in', (
      tester,
    ) async {
      final harness = await openSignIn(tester);
      await signUp(tester);

      expect(byKey('confirm.submit'), findsOneWidget);
      expect(fieldText(tester, 'confirm.email'), 'amal@example.test');
      expect(harness.auth.confirmationCodeFor('amal@example.test'), isNotNull);
    });

    testWidgets('a taken address keeps the name and email and offers sign-in', (
      tester,
    ) async {
      await openSignIn(tester);
      await signUp(tester, email: ' SARA@raad.test ');

      expect(find.text(en.emailInUse), findsOneWidget);
      expect(fieldText(tester, 'signUp.name'), 'Amal');
      expect(fieldText(tester, 'signUp.email'), ' SARA@raad.test ');
      await tapKey(tester, 'signUp.signInInstead');
      expect(byKey('signIn.submit'), findsOneWidget);
    });

    testWidgets('a password that breaks the rule is refused before any call', (
      tester,
    ) async {
      final harness = await openSignIn(tester);
      await signUp(tester, password: 'abcdef12');

      expect(find.text(en.passwordRuleBroken), findsOneWidget);
      expect(fieldText(tester, 'signUp.name'), 'Amal');
      expect(harness.auth.calls, isNot(contains(FakeAuthOperation.signUp)));
    });

    testWidgets('a rate limit has its own message', (tester) async {
      final harness = await openSignIn(tester);
      harness.auth.failNext(
        FakeAuthOperation.signUp,
        AuthFailureCode.rateLimited,
      );
      await signUp(tester);
      expect(textOf(tester, 'signUp.error'), en.tooManyAttempts);
    });

    testWidgets('the password is never stored on the phone', (tester) async {
      final harness = await openSignIn(tester);
      await signUp(tester, password: 'Secretpw9');
      expect(
        harness.store.values.values.any((v) => v.contains('Secretpw9')),
        isFalse,
      );
    });
  });

  group('Confirmation (S3)', () {
    testWidgets('a wrong code keeps the account unconfirmed', (tester) async {
      final harness = await openSignIn(tester);
      await signUp(tester);
      await enter(tester, 'confirm.code', '000000');
      await tapKey(tester, 'confirm.submit');

      expect(find.text(en.codeInvalid), findsOneWidget);
      expect(fieldText(tester, 'confirm.code'), '000000');
      expect(
        harness.directory.unconfirmedByEmail('amal@example.test'),
        isNotNull,
      );
    });

    testWidgets('the right code confirms, and the first sign-in opens a '
        'wallet with 1,000.00 SAR (AC1.2.1, AC1.2.3)', (tester) async {
      final harness = await openSignIn(tester);
      await signUp(tester);
      await enter(
        tester,
        'confirm.code',
        harness.auth.confirmationCodeFor('amal@example.test')!,
      );
      await tapKey(tester, 'confirm.submit');

      expect(textOf(tester, 'signIn.notice'), en.signInNoticeEmailConfirmed);
      expect(fieldText(tester, 'signIn.email'), 'amal@example.test');
      await enter(tester, 'signIn.password', 'Abcdef12');
      await tapKey(tester, 'signIn.submit');
      expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
      expect(harness.backend.countOf('PUT /wallet'), 1);
    });

    testWidgets('Send the code again answers the same for any address and '
        'replaces the earlier code (AC1.2.6)', (tester) async {
      final harness = await openSignIn(tester);
      await signUp(tester);
      final first = harness.auth.confirmationCodeFor('amal@example.test')!;
      await tapKey(tester, 'confirm.resend');
      expect(textOf(tester, 'confirm.note'), en.codeResent);

      await enter(tester, 'confirm.code', first);
      await tapKey(tester, 'confirm.submit');
      expect(find.text(en.codeInvalid), findsOneWidget);

      await enter(tester, 'confirm.email', 'nobody@example.test');
      await tapKey(tester, 'confirm.resend');
      expect(textOf(tester, 'confirm.note'), en.codeResent);
    });

    testWidgets('Send the code again is off while it runs', (tester) async {
      final harness = await openSignIn(tester);
      await tapKey(tester, 'signIn.haveCode');
      await enter(tester, 'confirm.email', fakeSara.email);
      harness.auth.delay = const Duration(seconds: 1);
      await tester.tap(byKey('confirm.resend'));
      await tester.pump();
      expect(buttonEnabled(tester, 'confirm.resend'), isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(buttonEnabled(tester, 'confirm.resend'), isTrue);
    });

    testWidgets('a rate-limited resend says so', (tester) async {
      final harness = await openSignIn(tester);
      await tapKey(tester, 'signIn.haveCode');
      await enter(tester, 'confirm.email', 'amal@example.test');
      harness.auth.failNext(
        FakeAuthOperation.resendCode,
        AuthFailureCode.rateLimited,
      );
      await tapKey(tester, 'confirm.resend');
      expect(textOf(tester, 'confirm.error'), en.tooManyAttempts);
    });

    testWidgets('sign-in offers the code screen for any address (AC1.3.3)', (
      tester,
    ) async {
      await openSignIn(tester);
      await tapKey(tester, 'signIn.haveCode');
      expect(byKey('confirm.submit'), findsOneWidget);
      expect(fieldText(tester, 'confirm.email'), isEmpty);
    });

    testWidgets('an unconfirmed account gets the one sign-in refusal', (
      tester,
    ) async {
      final harness = Harness();
      await harness.auth.signUp(
        email: 'amal@example.test',
        displayName: 'Amal',
        password: 'Abcdef12',
      );
      await openSignIn(tester, harness);
      await enter(tester, 'signIn.email', 'amal@example.test');
      await enter(tester, 'signIn.password', 'Abcdef12');
      await tapKey(tester, 'signIn.submit');
      expect(textOf(tester, 'signIn.error'), en.signInRefused);
    });
  });

  group('Forgot and reset password (S4, S5)', () {
    Future<void> askForCode(WidgetTester tester, String email) async {
      await tapKey(tester, 'signIn.forgot');
      await enter(tester, 'forgot.email', email);
      await tapKey(tester, 'forgot.submit');
    }

    testWidgets('a request answers the same for any address', (tester) async {
      await openSignIn(tester);
      await askForCode(tester, 'nobody@example.test');
      expect(textOf(tester, 'reset.sent'), en.resetCodeSent);
    });

    testWidgets('the code and a compliant password change it (AC1.5.1)', (
      tester,
    ) async {
      final harness = await openSignIn(tester);
      await askForCode(tester, ' Sara@RAAD.test ');
      await enter(
        tester,
        'reset.code',
        harness.auth.resetCodeFor(fakeSara.email)!,
      );
      await enter(tester, 'reset.password', 'Newpass12');
      await tapKey(tester, 'reset.submit');

      expect(textOf(tester, 'signIn.notice'), en.signInNoticePasswordChanged);
      await enter(tester, 'signIn.password', 'Newpass12');
      await tapKey(tester, 'signIn.submit');
      expect(byKey('wallet.balance'), findsOneWidget);
    });

    testWidgets('a wrong code or a rule-breaking password changes nothing '
        '(AC1.5.2, AC1.5.3)', (tester) async {
      final harness = await openSignIn(tester);
      await askForCode(tester, fakeSara.email);
      await enter(tester, 'reset.code', '999999');
      await enter(tester, 'reset.password', 'Newpass12');
      await tapKey(tester, 'reset.submit');
      expect(find.text(en.codeInvalid), findsOneWidget);

      await enter(
        tester,
        'reset.code',
        harness.auth.resetCodeFor(fakeSara.email)!,
      );
      await enter(tester, 'reset.password', 'newpass');
      await tapKey(tester, 'reset.submit');
      expect(find.text(en.passwordRuleBroken), findsOneWidget);
      expect(
        harness.directory.passwordOf(fakeSara),
        fakeSara.password,
        reason: 'nothing changed',
      );
    });

    testWidgets('an uncertain reset is not sent again and says what to do', (
      tester,
    ) async {
      final harness = await openSignIn(tester);
      await askForCode(tester, fakeSara.email);
      await enter(tester, 'reset.code', '123456');
      await enter(tester, 'reset.password', 'Newpass12');
      harness.auth.failNext(
        FakeAuthOperation.confirmReset,
        AuthFailureCode.network,
      );
      await tapKey(tester, 'reset.submit');

      expect(textOf(tester, 'reset.uncertain'), en.resetUncertain);
      await tester.tap(byKey('reset.submit'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        harness.auth.calls.where((c) => c == FakeAuthOperation.confirmReset),
        hasLength(1),
      );
      await tapKey(tester, 'reset.goToSignIn');
      expect(byKey('signIn.submit'), findsOneWidget);
    });

    testWidgets('a rate-limited request stays on the request screen', (
      tester,
    ) async {
      final harness = await openSignIn(tester);
      harness.auth.failNext(
        FakeAuthOperation.requestReset,
        AuthFailureCode.rateLimited,
      );
      await askForCode(tester, fakeSara.email);
      expect(textOf(tester, 'forgot.error'), en.tooManyAttempts);
      expect(byKey('reset.submit'), findsNothing);
    });
  });

  group('Sign-out and ended sessions', () {
    testWidgets('sign out from the account screen leaves nothing to go Back '
        'to (AC1.4.1, AC1.4.2)', (tester) async {
      final harness = Harness()..signedInAsSara();
      await openSignIn(tester, harness);
      await tapKey(tester, 'wallet.account');
      await tapKey(tester, 'account.signOut');

      expect(byKey('signIn.submit'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('wallet.balance'), findsNothing);
      expect(await harness.auth.hasSession(), isFalse);
    });

    testWidgets('reopening after 31 idle days asks for sign-in with a note', (
      tester,
    ) async {
      final harness = Harness()..signedInAsSara();
      harness.clock.advance(const Duration(days: 31));
      await openSignIn(tester, harness);

      expect(byKey('wallet.balance'), findsNothing);
      expect(textOf(tester, 'signIn.notice'), en.signInNoticeIdle);
    });

    testWidgets('reopening after 30 days opens the wallet', (tester) async {
      final harness = Harness()..signedInAsSara();
      harness.clock.advance(const Duration(days: 30));
      await openSignIn(tester, harness);
      expect(byKey('wallet.balance'), findsOneWidget);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/auth/cognito_auth_service.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';

import 'support/harness.dart';

void main() {
  group('SignInScreen', () {
    testWidgets('asks for both fields and sends nothing until they are given', (
      tester,
    ) async {
      final harness = Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await tapKey(tester, 'signIn.submit');

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(harness.auth.signInCalls, 0);
    });

    testWidgets('refuses an email address without a domain', (tester) async {
      final harness = Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await enter(tester, 'signIn.email', 'sara@raad');
      await enter(tester, 'signIn.password', 'anything');
      await tapKey(tester, 'signIn.submit');

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(harness.auth.signInCalls, 0);
    });

    testWidgets('signs in, sets up the wallet and shows the balance', (
      tester,
    ) async {
      final harness = Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await enter(tester, 'signIn.email', '  Sara@RAAD.test ');
      await enter(tester, 'signIn.password', fakeSara.password);
      await tapKey(tester, 'signIn.submit');

      expect(harness.auth.signedInAccount, fakeSara);
      expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
      expect(harness.backend.countOf('PUT /wallet'), 1);
      expect(byKey('app.environmentChip'), findsOneWidget);
    });

    testWidgets('gives one message for a wrong password and an unknown email', (
      tester,
    ) async {
      final harness = Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await enter(tester, 'signIn.email', fakeSara.email);
      await enter(tester, 'signIn.password', 'wrong-password');
      await tapKey(tester, 'signIn.submit');
      final wrongPassword = textOf(tester, 'signIn.error');

      await enter(tester, 'signIn.email', 'nobody@raad.test');
      await enter(tester, 'signIn.password', fakeSara.password);
      await tapKey(tester, 'signIn.submit');
      final unknownEmail = textOf(tester, 'signIn.error');

      expect(wrongPassword, en.signInRefused);
      expect(unknownEmail, wrongPassword);
      expect(harness.backend.requests, isEmpty);
    });

    testWidgets('shows a separate message when sign-in is rate limited', (
      tester,
    ) async {
      final harness = Harness();
      harness.auth.failNextSignIn = AuthFailureCode.rateLimited;
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await enter(tester, 'signIn.email', fakeSara.email);
      await enter(tester, 'signIn.password', fakeSara.password);
      await tapKey(tester, 'signIn.submit');

      expect(textOf(tester, 'signIn.error'), en.tooManyAttempts);
      expect(en.tooManyAttempts, isNot(en.signInRefused));
    });

    testWidgets('clears the error when either field changes', (tester) async {
      final harness = Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await enter(tester, 'signIn.email', fakeSara.email);
      await enter(tester, 'signIn.password', 'wrong-password');
      await tapKey(tester, 'signIn.submit');
      expect(byKey('signIn.error'), findsOneWidget);

      await enter(tester, 'signIn.password', 'wrong-password2');
      expect(byKey('signIn.error'), findsNothing);
    });

    testWidgets(
      'disables the button while signing in, so one tap is one call',
      (tester) async {
        final harness = Harness();
        harness.auth.signInDelay = const Duration(seconds: 1);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        await enter(tester, 'signIn.email', fakeSara.email);
        await enter(tester, 'signIn.password', fakeSara.password);
        await tester.tap(byKey('signIn.submit'));
        await tester.pump();
        await tester.tap(byKey('signIn.submit'), warnIfMissed: false);
        await tester.pump();

        expect(harness.auth.signInCalls, 1);
        await tester.pumpAndSettle();
        expect(byKey('wallet.balance'), findsOneWidget);
      },
    );

    testWidgets('opens the wallet directly when a session already exists', (
      tester,
    ) async {
      final harness = Harness()..signedInAsSara();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(byKey('signIn.submit'), findsNothing);
      expect(byKey('wallet.balance'), findsOneWidget);
    });
  });

  group('Cognito error mapping (C3 checks P6 and P11)', () {
    test('every wrong-credential case becomes one SIGN_IN_FAILED', () {
      for (final code in [
        'NotAuthorizedException',
        'UserNotFoundException',
        'UserNotConfirmedException',
        'PasswordResetRequiredException',
        'InvalidParameterException',
        'SomethingNewException',
        null,
      ]) {
        expect(mapCognitoSignInError(code), AuthFailureCode.signInFailed);
      }
    });

    test('rate limits and network failures keep their own codes', () {
      expect(
        mapCognitoSignInError('TooManyRequestsException'),
        AuthFailureCode.rateLimited,
      );
      expect(
        mapCognitoSignInError('LimitExceededException'),
        AuthFailureCode.rateLimited,
      );
      expect(
        mapCognitoSignInError('TooManyFailedAttemptsException'),
        AuthFailureCode.rateLimited,
      );
      expect(mapCognitoSignInError('NetworkError'), AuthFailureCode.network);
    });

    test('normalizes the email the way C3 asks', () {
      expect(normalizeEmail('  Sara@RAAD.test\t'), 'sara@raad.test');
      expect(looksLikeEmail(' Omar@raad.test '), isTrue);
      expect(looksLikeEmail('omar@raad'), isFalse);
      expect(looksLikeEmail('omar raad@x.test'), isFalse);
    });
  });
}

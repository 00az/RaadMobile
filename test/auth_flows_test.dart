// Account actions as C3 describes them, through the fake sign-in the widget
// tests and integration journeys use: the A4 password rule, one sign-in
// refusal, a resent code that replaces every earlier one, one
// acknowledgement for any address, and password reset (US1.1 to US1.5).

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';

Matcher failsWith(AuthFailureCode code) =>
    throwsA(isA<AuthFailure>().having((f) => f.code, 'code', code));

void main() {
  group('A4 password rule (C3 password_rule examples)', () {
    test('accepts Abcdef12, needing no symbol', () {
      expect(meetsPasswordRule('Abcdef12'), isTrue);
      expect(meetsPasswordRule('Local-preview-1'), isTrue);
    });

    test('refuses each of the four examples that break it', () {
      for (final password in ['abcdef12', 'ABCDEF12', 'Abcdefgh', 'Abcde12']) {
        expect(meetsPasswordRule(password), isFalse, reason: password);
      }
    });

    test('Arabic letters do not stand in for Latin upper or lower case', () {
      expect(meetsPasswordRule('كلمةسر12A'), isFalse);
    });
  });

  test('email and code helpers', () {
    expect(normalizeEmail('  Amal@Example.TEST\t'), 'amal@example.test');
    expect(normalizeCode(' 123 456 '), '123456');
  });

  group('Sign-up and confirmation', () {
    late FakeAuthService auth;

    setUp(() => auth = FakeAuthService());

    test(
      'a sign-up makes an unconfirmed account that cannot sign in',
      () async {
        await auth.signUp(
          email: ' Amal@Example.test ',
          displayName: ' Amal ',
          password: 'Abcdef12',
        );
        expect(auth.confirmationCodeFor('amal@example.test'), isNotNull);
        await expectLater(
          auth.signIn(email: 'amal@example.test', password: 'Abcdef12'),
          failsWith(AuthFailureCode.signInFailed),
        );
      },
    );

    test('the same address in other capitals and spaces is in use', () async {
      await auth.signUp(
        email: 'a@x.test',
        displayName: 'A',
        password: 'Abcdef12',
      );
      await expectLater(
        auth.signUp(
          email: ' A@X.test ',
          displayName: 'B',
          password: 'Abcdef12',
        ),
        failsWith(AuthFailureCode.emailInUse),
      );
    });

    test('a password that breaks the rule is refused', () async {
      await expectLater(
        auth.signUp(
          email: 'amal@example.test',
          displayName: 'Amal',
          password: 'abcdef12',
        ),
        failsWith(AuthFailureCode.passwordRuleFailed),
      );
    });

    test('a wrong code keeps the account unconfirmed; the right one '
        'confirms it', () async {
      await auth.signUp(
        email: 'amal@example.test',
        displayName: 'Amal',
        password: 'Abcdef12',
      );
      await expectLater(
        auth.confirmSignUp(email: 'amal@example.test', code: '000000'),
        failsWith(AuthFailureCode.codeInvalidOrExpired),
      );
      final code = auth.confirmationCodeFor('amal@example.test')!;
      await auth.confirmSignUp(email: 'AMAL@example.test', code: ' $code ');
      await auth.signIn(email: 'amal@example.test', password: 'Abcdef12');
      expect(auth.signedInAccount!.displayName, 'Amal');
    });

    test('a resent code replaces the earlier one', () async {
      await auth.signUp(
        email: 'amal@example.test',
        displayName: 'Amal',
        password: 'Abcdef12',
      );
      final first = auth.confirmationCodeFor('amal@example.test')!;
      await auth.resendConfirmationCode(email: 'amal@example.test');
      final second = auth.confirmationCodeFor('amal@example.test')!;
      expect(second, isNot(first));
      await expectLater(
        auth.confirmSignUp(email: 'amal@example.test', code: first),
        failsWith(AuthFailureCode.codeInvalidOrExpired),
      );
      await auth.confirmSignUp(email: 'amal@example.test', code: second);
    });

    test(
      'a resend answers the same for unknown and confirmed addresses',
      () async {
        await auth.resendConfirmationCode(email: 'nobody@example.test');
        await auth.resendConfirmationCode(email: fakeSara.email);
        auth.failNext(
          FakeAuthOperation.resendCode,
          AuthFailureCode.rateLimited,
        );
        await expectLater(
          auth.resendConfirmationCode(email: 'nobody@example.test'),
          failsWith(AuthFailureCode.rateLimited),
        );
      },
    );
  });

  group('Password reset', () {
    late FakeAuthService auth;

    setUp(() => auth = FakeAuthService());

    test('a reset with the emailed code changes the password', () async {
      await auth.requestPasswordReset(email: ' SARA@raad.test ');
      final code = auth.resetCodeFor(fakeSara.email)!;
      await auth.confirmPasswordReset(
        email: fakeSara.email,
        code: code,
        newPassword: 'Newpass12',
      );
      await expectLater(
        auth.signIn(email: fakeSara.email, password: fakeSara.password),
        failsWith(AuthFailureCode.signInFailed),
      );
      await auth.signIn(email: fakeSara.email, password: 'Newpass12');
    });

    test('a wrong code or a rule-breaking password changes nothing', () async {
      await auth.requestPasswordReset(email: fakeSara.email);
      final code = auth.resetCodeFor(fakeSara.email)!;
      await expectLater(
        auth.confirmPasswordReset(
          email: fakeSara.email,
          code: '999999',
          newPassword: 'Newpass12',
        ),
        failsWith(AuthFailureCode.codeInvalidOrExpired),
      );
      await expectLater(
        auth.confirmPasswordReset(
          email: fakeSara.email,
          code: code,
          newPassword: 'newpass',
        ),
        failsWith(AuthFailureCode.passwordRuleFailed),
      );
      await auth.signIn(email: fakeSara.email, password: fakeSara.password);
    });

    test('a reset request answers the same for an unknown address', () async {
      await auth.requestPasswordReset(email: 'nobody@example.test');
      expect(auth.resetCodeFor('nobody@example.test'), isNull);
    });
  });
}

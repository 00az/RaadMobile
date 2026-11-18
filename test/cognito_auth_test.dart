// The Cognito sign-in adapter against a stubbed Cognito API: token reuse,
// refresh, the C3 error mapping and sign-out. No network is used.

import 'dart:convert';

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/auth/cognito_auth_service.dart';
import 'package:raad_mobile/auth/jwt.dart';
import 'package:raad_mobile/auth/session_store.dart';
import 'package:raad_mobile/config/environment_config.dart';

final now = DateTime.utc(2026, 11, 14, 12);

String jwt(Map<String, Object?> claims) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'RS256', 'kid': 'k'})}.${part(claims)}.c2ln';
}

String accessToken({
  required DateTime expires,
  String? username = 'sara-sub',
}) => jwt({
  'sub': 'sara-sub',
  'token_use': 'access',
  'client_id': 'client123',
  'username': ?username,
  'exp': expires.millisecondsSinceEpoch ~/ 1000,
  'iat': now.millisecondsSinceEpoch ~/ 1000,
});

final class StubCognito extends Client {
  StubCognito() : super(region: 'us-east-1');

  final List<String> operations = [];
  final List<Map<String, dynamic>> params = [];
  Object? Function(String operation)? answer;

  @override
  dynamic request(
    String operation,
    Map<String, dynamic> params, {
    String? endpoint,
    String? service,
  }) async {
    operations.add(operation);
    this.params.add(params);
    final result = answer?.call(operation);
    if (result is Exception) throw result;
    return result;
  }
}

void main() {
  late StubCognito cognito;
  late MemorySessionStore store;
  late CognitoAuthService auth;

  final config = EnvironmentConfig.parse({
    'configVersion': '1.0',
    'environment': 'dev',
    'apiBaseUrl': 'https://api.dev.raad.example',
    'moneyBasePath': '/money/v1',
    'authIssuer':
        'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_Test123',
    'authAudience': 'client123',
    'authClientId': 'client123',
  });

  setUp(() {
    cognito = StubCognito();
    store = MemorySessionStore();
    auth = CognitoAuthService(
      config: config,
      store: store,
      pool: CognitoUserPool(
        config.userPoolId,
        config.authClientId,
        customClient: cognito,
      ),
      now: () => now,
    );
  });

  test('reads the expiry from the token', () {
    final token = accessToken(expires: now.add(const Duration(minutes: 30)));
    expect(jwtExpiry(token), now.add(const Duration(minutes: 30)));
    expect(jwtIsExpired(token, now: now), isFalse);
    expect(
      jwtIsExpired(
        token,
        now: now.add(const Duration(minutes: 29, seconds: 30)),
      ),
      isTrue,
      reason: 'a token about to expire is refreshed early',
    );
    expect(jwtIsExpired('not-a-jwt', now: now), isTrue);
    expect(jwtPayload('a.%%%.c'), isNull);
  });

  test('uses a current token without calling Cognito', () async {
    final token = accessToken(expires: now.add(const Duration(minutes: 30)));
    await store.save(StoredSession(accessToken: token, refreshToken: 'r1'));

    expect(await auth.hasSession(), isTrue);
    expect(await auth.accessToken(), token);
    expect(cognito.operations, isEmpty);
  });

  test('refreshes an expired token and keeps the refresh token', () async {
    final fresh = accessToken(expires: now.add(const Duration(minutes: 60)));
    await store.save(
      StoredSession(
        accessToken: accessToken(
          expires: now.subtract(const Duration(minutes: 1)),
        ),
        refreshToken: 'r1',
      ),
    );
    cognito.answer = (_) => {
      'AuthenticationResult': {
        'AccessToken': fresh,
        'IdToken': jwt({'sub': 'sara-sub', 'exp': 0}),
      },
    };

    expect(await auth.accessToken(), fresh);
    expect(cognito.operations, ['InitiateAuth']);
    expect(cognito.params.single['AuthFlow'], 'REFRESH_TOKEN_AUTH');
    final saved = await store.read();
    expect(saved!.accessToken, fresh);
    expect(saved.refreshToken, 'r1');
  });

  test('a refused refresh ends the session', () async {
    await store.save(
      StoredSession(
        accessToken: accessToken(
          expires: now.subtract(const Duration(hours: 1)),
        ),
        refreshToken: 'r1',
      ),
    );
    cognito.answer = (_) =>
        CognitoClientException('expired', code: 'NotAuthorizedException');

    expect(await auth.accessToken(), isNull);
    expect(await store.read(), isNull);
  });

  test('a refresh that cannot reach Cognito keeps the session', () async {
    await store.save(
      StoredSession(
        accessToken: accessToken(
          expires: now.subtract(const Duration(hours: 1)),
        ),
        refreshToken: 'r1',
      ),
    );
    cognito.answer = (_) =>
        CognitoClientException('SocketException', code: 'NetworkError');

    await expectLater(
      auth.accessToken(),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.code,
          'code',
          AuthFailureCode.network,
        ),
      ),
    );
    expect(await store.read(), isNotNull);
  });

  test('an expired token without a username asks for sign-in', () async {
    await store.save(
      StoredSession(
        accessToken: accessToken(
          expires: now.subtract(const Duration(hours: 1)),
          username: null,
        ),
        refreshToken: 'r1',
      ),
    );

    expect(await auth.accessToken(), isNull);
    expect(cognito.operations, isEmpty);
    expect(await auth.hasSession(), isFalse);
  });

  test('sign-in refusals map to the C3 codes', () async {
    for (final (cognitoCode, expected) in [
      ('UserNotFoundException', AuthFailureCode.signInFailed),
      ('NotAuthorizedException', AuthFailureCode.signInFailed),
      ('UserNotConfirmedException', AuthFailureCode.signInFailed),
      ('TooManyRequestsException', AuthFailureCode.rateLimited),
    ]) {
      cognito.answer = (_) => CognitoClientException('x', code: cognitoCode);
      await expectLater(
        auth.signIn(email: ' Sara@RAAD.test ', password: 'pw'),
        throwsA(isA<AuthFailure>().having((f) => f.code, 'code', expected)),
        reason: cognitoCode,
      );
    }
    final firstCall = cognito.params.first;
    expect(firstCall['AuthFlow'], 'USER_SRP_AUTH');
    expect(
      (firstCall['AuthParameters'] as Map)['USERNAME'],
      'sara@raad.test',
      reason: 'the email is normalized before it is sent',
    );
    expect(await store.read(), isNull);
  });

  test('reads the account from the stored access token', () async {
    expect(await auth.currentAccountId(), isNull);
    await store.save(
      StoredSession(
        accessToken: accessToken(expires: now.add(const Duration(hours: 1))),
        refreshToken: 'r1',
      ),
    );
    expect(await auth.currentAccountId(), 'sara-sub');
  });

  test('concurrent requests with an expired token share one refresh', () async {
    final fresh = accessToken(expires: now.add(const Duration(minutes: 60)));
    await store.save(
      StoredSession(
        accessToken: accessToken(
          expires: now.subtract(const Duration(minutes: 1)),
        ),
        refreshToken: 'r1',
      ),
    );
    cognito.answer = (_) => {
      'AuthenticationResult': {
        'AccessToken': fresh,
        'IdToken': jwt({'sub': 'sara-sub', 'exp': 0}),
      },
    };
    final tokens = await Future.wait([
      auth.accessToken(),
      auth.accessToken(),
      auth.accessToken(),
    ]);
    expect(tokens, [fresh, fresh, fresh]);
    expect(cognito.operations, ['InitiateAuth']);
  });

  group('account actions (C3)', () {
    test(
      'sign-up sends the normalized email, the name and nothing else',
      () async {
        cognito.answer = (_) => {'UserConfirmed': false, 'UserSub': 'new-sub'};
        await auth.signUp(
          email: ' Amal@Example.TEST ',
          displayName: ' Amal ',
          password: 'Abcdef12',
        );
        expect(cognito.operations, ['SignUp']);
        final params = cognito.params.single;
        expect(params['Username'], 'amal@example.test');
        final attributes = {
          for (final a in params['UserAttributes'] as List<AttributeArg>)
            a.name: a.value,
        };
        expect(attributes, {'email': 'amal@example.test', 'name': 'Amal'});
      },
    );

    test('sign-up refusals map to the C3 codes', () async {
      for (final (cognitoCode, expected) in [
        ('UsernameExistsException', AuthFailureCode.emailInUse),
        ('InvalidPasswordException', AuthFailureCode.passwordRuleFailed),
        ('TooManyRequestsException', AuthFailureCode.rateLimited),
        ('NetworkError', AuthFailureCode.network),
        ('CodeDeliveryFailureException', AuthFailureCode.failed),
      ]) {
        cognito.answer = (_) => CognitoClientException('x', code: cognitoCode);
        await expectLater(
          auth.signUp(email: 'a@x.test', displayName: 'A', password: 'p'),
          throwsA(isA<AuthFailure>().having((f) => f.code, 'code', expected)),
          reason: cognitoCode,
        );
      }
    });

    test('confirmation and reset codes map to the C3 codes', () {
      for (final code in [
        'CodeMismatchException',
        'ExpiredCodeException',
        'UserNotFoundException',
        'NotAuthorizedException',
      ]) {
        expect(
          mapCognitoCodeError(code),
          AuthFailureCode.codeInvalidOrExpired,
          reason: code,
        );
      }
      expect(
        mapCognitoCodeError('InvalidPasswordException'),
        AuthFailureCode.passwordRuleFailed,
      );
      expect(
        mapCognitoCodeError('LimitExceededException'),
        AuthFailureCode.rateLimited,
      );
      expect(mapCognitoCodeError('NetworkError'), AuthFailureCode.network);
      expect(mapCognitoCodeError('Surprise'), AuthFailureCode.failed);
    });

    test('confirmation sends the code without spaces', () async {
      cognito.answer = (_) => <String, Object?>{};
      await auth.confirmSignUp(email: ' Amal@Example.test ', code: '12 34 56');
      expect(cognito.operations, ['ConfirmSignUp']);
      expect(cognito.params.single['Username'], 'amal@example.test');
      expect(cognito.params.single['ConfirmationCode'], '123456');

      cognito.answer = (_) =>
          CognitoClientException('x', code: 'CodeMismatchException');
      await expectLater(
        auth.confirmSignUp(email: 'amal@example.test', code: '1'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.codeInvalidOrExpired,
          ),
        ),
      );
    });

    test('resend and reset requests acknowledge every answer but a limit '
        'or the network', () async {
      for (final cognitoCode in [
        'UserNotFoundException',
        'InvalidParameterException',
        'NotAuthorizedException',
      ]) {
        cognito.answer = (_) => CognitoClientException('x', code: cognitoCode);
        await auth.resendConfirmationCode(email: 'nobody@x.test');
        await auth.requestPasswordReset(email: 'nobody@x.test');
      }
      cognito.answer = (_) =>
          CognitoClientException('x', code: 'LimitExceededException');
      await expectLater(
        auth.resendConfirmationCode(email: 'a@x.test'),
        throwsA(isA<AuthFailure>()),
      );
      cognito.answer = (_) => CognitoClientException('x', code: 'NetworkError');
      await expectLater(
        auth.requestPasswordReset(email: 'a@x.test'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.network,
          ),
        ),
      );
      expect(cognito.operations.toSet(), {
        'ResendConfirmationCode',
        'ForgotPassword',
      });
    });

    test('a password reset sends the code and the new password', () async {
      cognito.answer = (_) => <String, Object?>{};
      await auth.confirmPasswordReset(
        email: 'SARA@raad.test',
        code: ' 654321 ',
        newPassword: 'Newpass12',
      );
      expect(cognito.operations, ['ConfirmForgotPassword']);
      expect(cognito.params.single['Username'], 'sara@raad.test');
      expect(cognito.params.single['ConfirmationCode'], '654321');
      expect(cognito.params.single['Password'], 'Newpass12');
    });
  });

  test('sign-out removes the tokens and revokes the refresh token', () async {
    await store.save(
      StoredSession(
        accessToken: accessToken(expires: now.add(const Duration(minutes: 5))),
        refreshToken: 'r1',
      ),
    );
    cognito.answer = (_) =>
        CognitoClientException('offline', code: 'NetworkError');

    await auth.signOut();

    expect(await store.read(), isNull);
    expect(cognito.operations, ['RevokeToken']);
    expect(cognito.params.single['Token'], 'r1');

    cognito.operations.clear();
    await auth.signOut();
    expect(cognito.operations, isEmpty);
  });
}

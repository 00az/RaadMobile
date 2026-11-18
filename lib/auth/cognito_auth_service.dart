/// The C3 sign-in adapter for Amazon Cognito (user SRP flow, public client
/// with no secret). It maps every provider error to a stable C3 code and
/// never passes provider text to a screen.
library;

import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import '../config/environment_config.dart';
import 'auth_service.dart';
import 'jwt.dart';
import 'session_store.dart';

const _rateLimitCodes = {
  'TooManyRequestsException',
  'LimitExceededException',
  'TooManyFailedAttemptsException',
};

/// Maps a Cognito error code to the C3 client code (checks P6 and P11).
///
/// Wrong password, unknown user and unconfirmed account all become
/// [AuthFailureCode.signInFailed]; any error not listed here does too, so
/// provider text never reaches the screen.
AuthFailureCode mapCognitoSignInError(String? cognitoCode) {
  if (_rateLimitCodes.contains(cognitoCode)) return AuthFailureCode.rateLimited;
  if (cognitoCode == 'NetworkError') return AuthFailureCode.network;
  return AuthFailureCode.signInFailed;
}

/// Sign-up: `EMAIL_IN_USE`, `PASSWORD_RULE_FAILED` and `RATE_LIMITED`.
AuthFailureCode mapCognitoSignUpError(String? cognitoCode) {
  return switch (cognitoCode) {
    'UsernameExistsException' ||
    'AliasExistsException' => AuthFailureCode.emailInUse,
    'InvalidPasswordException' => AuthFailureCode.passwordRuleFailed,
    'NetworkError' => AuthFailureCode.network,
    final code when _rateLimitCodes.contains(code) =>
      AuthFailureCode.rateLimited,
    _ => AuthFailureCode.failed,
  };
}

/// Confirming an account or a password reset with an emailed code. An
/// unknown or already confirmed account reads as a code that is not valid,
/// so the screen reveals nothing about the address.
AuthFailureCode mapCognitoCodeError(String? cognitoCode) {
  return switch (cognitoCode) {
    'CodeMismatchException' ||
    'ExpiredCodeException' ||
    'UserNotFoundException' ||
    'NotAuthorizedException' => AuthFailureCode.codeInvalidOrExpired,
    'InvalidPasswordException' => AuthFailureCode.passwordRuleFailed,
    'NetworkError' => AuthFailureCode.network,
    final code when _rateLimitCodes.contains(code) =>
      AuthFailureCode.rateLimited,
    _ => AuthFailureCode.failed,
  };
}

/// A resend or a reset request: only a rate limit or a network failure is
/// reported; every other answer is the same acknowledgement (P7, P8).
AuthFailureCode? mapCognitoAcknowledgedError(String? cognitoCode) {
  if (_rateLimitCodes.contains(cognitoCode)) return AuthFailureCode.rateLimited;
  if (cognitoCode == 'NetworkError') return AuthFailureCode.network;
  return null;
}

final class CognitoAuthService implements AuthService {
  CognitoAuthService({
    required EnvironmentConfig config,
    required this._store,
    CognitoUserPool? pool,
    DateTime Function()? now,
  }) : _pool = pool ?? CognitoUserPool(config.userPoolId, config.authClientId),
       _now = now ?? DateTime.now;

  final CognitoUserPool _pool;
  final SessionStore _store;
  final DateTime Function() _now;

  /// One refresh shared by every request that finds the token expired.
  Future<String?>? _refreshing;

  CognitoUser _user(String email) => CognitoUser(normalizeEmail(email), _pool);

  @override
  Future<void> signIn({required String email, required String password}) async {
    final username = normalizeEmail(email);
    CognitoUserSession? session;
    try {
      session = await CognitoUser(username, _pool).authenticateUser(
        AuthenticationDetails(username: username, password: password),
      );
    } on CognitoClientException catch (error) {
      throw AuthFailure(mapCognitoSignInError(error.code));
    } on CognitoUserException {
      // A challenge the app does not support (new password, MFA,
      // confirmation) reads as the one sign-in refusal.
      throw const AuthFailure(AuthFailureCode.signInFailed);
    }
    final access = session?.getAccessToken().getJwtToken();
    final refresh = session?.getRefreshToken()?.getToken();
    if (access == null || refresh == null) {
      throw const AuthFailure(AuthFailureCode.signInFailed);
    }
    await _store.save(
      StoredSession(accessToken: access, refreshToken: refresh),
    );
  }

  @override
  Future<void> signUp({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final username = normalizeEmail(email);
    try {
      await _pool.signUp(
        username,
        password,
        userAttributes: [
          AttributeArg(name: 'email', value: username),
          // The pool's required `fullname` standard attribute is `name`.
          AttributeArg(name: 'name', value: displayName.trim()),
        ],
      );
    } on CognitoClientException catch (error) {
      throw AuthFailure(mapCognitoSignUpError(error.code));
    }
  }

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    try {
      await _user(email).confirmRegistration(normalizeCode(code));
    } on CognitoClientException catch (error) {
      throw AuthFailure(mapCognitoCodeError(error.code));
    }
  }

  @override
  Future<void> resendConfirmationCode({required String email}) =>
      _acknowledged(() async {
        await _user(email).resendConfirmationCode();
      });

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _acknowledged(() async {
        await _user(email).forgotPassword();
      });

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _user(email).confirmPassword(normalizeCode(code), newPassword);
    } on CognitoClientException catch (error) {
      throw AuthFailure(mapCognitoCodeError(error.code));
    }
  }

  Future<void> _acknowledged(Future<void> Function() call) async {
    try {
      await call();
    } on CognitoClientException catch (error) {
      final failure = mapCognitoAcknowledgedError(error.code);
      if (failure != null) throw AuthFailure(failure);
    }
  }

  @override
  Future<bool> hasSession() async => await _store.read() != null;

  @override
  Future<String?> currentAccountId() async {
    final stored = await _store.read();
    if (stored == null) return null;
    final sub = jwtPayload(stored.accessToken)?['sub'];
    return sub is String && sub.isNotEmpty ? sub : null;
  }

  @override
  Future<String?> accessToken() async {
    final stored = await _store.read();
    if (stored == null) return null;
    if (!jwtIsExpired(stored.accessToken, now: _now())) {
      return stored.accessToken;
    }
    return _refreshing ??= _refresh(stored)
        .whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh(StoredSession stored) async {
    final username = jwtPayload(stored.accessToken)?['username'];
    if (username is! String || username.isEmpty) {
      await _store.clear();
      return null;
    }
    try {
      final session = await CognitoUser(
        username,
        _pool,
      ).refreshSession(CognitoRefreshToken(stored.refreshToken));
      final access = session?.getAccessToken().getJwtToken();
      if (access == null) {
        await _store.clear();
        return null;
      }
      final refresh =
          session?.getRefreshToken()?.getToken() ?? stored.refreshToken;
      await _store.save(
        StoredSession(accessToken: access, refreshToken: refresh),
      );
      return access;
    } on CognitoClientException catch (error) {
      if (mapCognitoSignInError(error.code) == AuthFailureCode.network) {
        throw const AuthFailure(AuthFailureCode.network);
      }
      await _store.clear();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    final stored = await _store.read();
    await _store.clear();
    if (stored == null) return;
    try {
      await _pool.client?.request('RevokeToken', {
        'ClientId': _pool.getClientId(),
        'Token': stored.refreshToken,
      });
    } on Object {
      // Best effort: the local tokens are already gone.
    }
  }
}

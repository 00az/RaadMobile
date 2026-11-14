/// The C3 sign-in adapter for Amazon Cognito (user SRP flow, public client
/// with no secret). It maps every provider error to a stable C3 code.
library;

import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import '../config/environment_config.dart';
import 'auth_service.dart';
import 'jwt.dart';
import 'session_store.dart';

/// Maps a Cognito error code to the C3 client code (checks P6 and P11).
///
/// Wrong password, unknown user and unconfirmed account all become
/// [AuthFailureCode.signInFailed]; any error not listed here does too, so
/// provider text never reaches the screen.
AuthFailureCode mapCognitoSignInError(String? cognitoCode) {
  return switch (cognitoCode) {
    'TooManyRequestsException' ||
    'LimitExceededException' ||
    'TooManyFailedAttemptsException' => AuthFailureCode.rateLimited,
    'NetworkError' => AuthFailureCode.network,
    _ => AuthFailureCode.signInFailed,
  };
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

  @override
  Future<void> signIn({required String email, required String password}) async {
    final username = normalizeEmail(email);
    final user = CognitoUser(username, _pool);
    CognitoUserSession? session;
    try {
      session = await user.authenticateUser(
        AuthenticationDetails(username: username, password: password),
      );
    } on CognitoClientException catch (error) {
      throw AuthFailure(mapCognitoSignInError(error.code));
    } on CognitoUserException {
      // A challenge U1 does not support (new password, MFA, confirmation).
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
  Future<bool> hasSession() async => await _store.read() != null;

  @override
  Future<String?> accessToken() async {
    final stored = await _store.read();
    if (stored == null) return null;
    if (!jwtIsExpired(stored.accessToken, now: _now())) {
      return stored.accessToken;
    }
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

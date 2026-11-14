/// Sign-in as the app sees it, independent of the provider SDK (contract C3).
library;

/// The stable client codes of C3. Screens branch on these, never on provider
/// text.
enum AuthFailureCode {
  /// Wrong password, unknown email and unconfirmed account all give this one
  /// code, so the app never reveals which part was wrong.
  signInFailed,
  rateLimited,
  sessionExpired,
  network,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}

abstract interface class AuthService {
  /// Signs in and keeps the tokens in secure storage.
  ///
  /// Throws [AuthFailure] with [AuthFailureCode.signInFailed],
  /// [AuthFailureCode.rateLimited] or [AuthFailureCode.network].
  Future<void> signIn({required String email, required String password});

  /// Whether a stored session exists. It may still need a refresh.
  Future<bool> hasSession();

  /// A current access token, refreshed when it has expired, or null when the
  /// person must sign in again.
  ///
  /// Throws [AuthFailure] with [AuthFailureCode.network] when the refresh
  /// could not reach the provider.
  Future<String?> accessToken();

  /// Removes the local tokens, and revokes the refresh token when it can.
  Future<void> signOut();
}

/// Trims surrounding whitespace and lowercases, as C3 asks of the client
/// before every account call and C1 before every recipient lookup.
String normalizeEmail(String input) => input.trim().toLowerCase();

final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// A light format check for early feedback; the server stays authoritative.
bool looksLikeEmail(String input) =>
    _emailShape.hasMatch(normalizeEmail(input));

/// Account actions as the app sees them, independent of the provider SDK
/// (contract C3, `raad-sign-in-client-profile` 1.0).
library;

/// The stable client codes of C3. Screens branch on these, never on provider
/// text (check P11).
enum AuthFailureCode {
  /// Wrong password, unknown email and unconfirmed account all give this one
  /// code, so the app never reveals which part was wrong (check P6).
  signInFailed,
  rateLimited,
  sessionExpired,
  network,

  /// Sign-up only: the address already has an account (FR1.6 allows this).
  emailInUse,

  /// The password does not meet the A4 rule.
  passwordRuleFailed,

  /// A confirmation or reset code that is wrong or has expired.
  codeInvalidOrExpired,

  /// Any provider answer not listed above; shown as the generic failure.
  failed,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}

/// Where the Money API client gets the bearer token for each request.
abstract interface class TokenSource {
  /// A current access token, or null when the person must sign in again.
  Future<String?> accessToken();
}

/// Every method normalizes the email address itself (trimmed, lowercased),
/// so callers may pass it as typed. Passwords and codes are passed through
/// to the provider and never stored or logged.
abstract interface class AuthService implements TokenSource {
  /// Signs in and keeps the tokens in secure storage.
  ///
  /// Throws [AuthFailure] with [AuthFailureCode.signInFailed],
  /// [AuthFailureCode.rateLimited] or [AuthFailureCode.network].
  Future<void> signIn({required String email, required String password});

  /// Creates an unconfirmed account and has a code emailed (US1.1).
  ///
  /// Throws [AuthFailure] with [AuthFailureCode.emailInUse],
  /// [AuthFailureCode.passwordRuleFailed], [AuthFailureCode.rateLimited],
  /// [AuthFailureCode.network] or [AuthFailureCode.failed].
  Future<void> signUp({
    required String email,
    required String displayName,
    required String password,
  });

  /// Confirms an account with the emailed code (US1.2).
  ///
  /// Throws [AuthFailure] with [AuthFailureCode.codeInvalidOrExpired],
  /// [AuthFailureCode.rateLimited], [AuthFailureCode.network] or
  /// [AuthFailureCode.failed].
  Future<void> confirmSignUp({required String email, required String code});

  /// Asks for a new confirmation code. Every outcome but a rate limit or a
  /// network failure completes normally, so the screen shows the same
  /// acknowledgement for any address (AC1.2.6, check P7).
  Future<void> resendConfirmationCode({required String email});

  /// Asks for a password-reset code. Every outcome but a rate limit or a
  /// network failure completes normally (check P8).
  Future<void> requestPasswordReset({required String email});

  /// Sets a new password with the emailed reset code (US1.5).
  ///
  /// Throws [AuthFailure] with [AuthFailureCode.codeInvalidOrExpired],
  /// [AuthFailureCode.passwordRuleFailed], [AuthFailureCode.rateLimited],
  /// [AuthFailureCode.network] or [AuthFailureCode.failed]. A network
  /// failure leaves it unknown whether the password changed.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Whether a stored session exists. It may still need a refresh.
  Future<bool> hasSession();

  /// The verified account (`sub`) of the stored session, or null.
  Future<String?> currentAccountId();

  /// A current access token, refreshed when it has expired, or null when the
  /// person must sign in again.
  ///
  /// Throws [AuthFailure] with [AuthFailureCode.network] when the refresh
  /// could not reach the provider.
  @override
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

/// Removes spaces from a typed or pasted code.
String normalizeCode(String input) => input.replaceAll(RegExp(r'\s'), '');

/// The A4 password rule from C3: at least 8 characters with a Latin
/// lower-case letter, a Latin upper-case letter and a digit. No symbol is
/// required. The provider checks it again.
bool meetsPasswordRule(String password) =>
    password.length >= 8 &&
    RegExp('[a-z]').hasMatch(password) &&
    RegExp('[A-Z]').hasMatch(password) &&
    RegExp('[0-9]').hasMatch(password);

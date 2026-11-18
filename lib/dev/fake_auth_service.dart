/// A sign-in service for tests, the integration journeys and the offline
/// preview. It follows the C3 client behaviour: one SIGN_IN_FAILED for every
/// wrong credential (an unconfirmed account included), one acknowledgement
/// for every resend and reset request, and a resent code that replaces every
/// earlier one.
library;

import '../auth/auth_service.dart';
import 'fake_accounts.dart';

/// The account actions [FakeAuthService.failNext] can refuse.
enum FakeAuthOperation {
  signIn,
  signUp,
  confirmSignUp,
  resendCode,
  requestReset,
  confirmReset,
}

final class FakeAuthService implements AuthService {
  FakeAuthService({FakeDirectory? directory})
    : directory = directory ?? FakeDirectory();

  final FakeDirectory directory;
  FakeAccount? _signedIn;
  final Map<String, String> _confirmationCodes = {};
  final Map<String, String> _resetCodes = {};
  final Map<FakeAuthOperation, AuthFailureCode> _failures = {};
  int _codeCounter = 100000;

  /// When set, the next sign-in fails with this code.
  AuthFailureCode? failNextSignIn;

  /// When true, [accessToken] reports that the session has expired.
  bool expireSession = false;

  /// Delay before an account action answers, to observe busy states.
  Duration delay = Duration.zero;

  /// Kept for older tests: the same as [delay].
  set signInDelay(Duration value) => delay = value;

  int signInCalls = 0;
  int tokenCalls = 0;
  final List<FakeAuthOperation> calls = [];

  FakeAccount? get signedInAccount => _signedIn;

  void signInAs(FakeAccount account) => _signedIn = account;

  /// Makes the next [operation] fail with [code].
  void failNext(FakeAuthOperation operation, AuthFailureCode code) =>
      _failures[operation] = code;

  /// The code most recently emailed to [email] to confirm the account; a
  /// resend replaces it.
  String? confirmationCodeFor(String email) =>
      _confirmationCodes[normalizeEmail(email)];

  /// The code most recently emailed to [email] to reset the password.
  String? resetCodeFor(String email) => _resetCodes[normalizeEmail(email)];

  Future<void> _start(FakeAuthOperation operation) async {
    calls.add(operation);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = _failures.remove(operation);
    if (failure != null) throw AuthFailure(failure);
  }

  String _issueCode() => '${++_codeCounter}';

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    final failure = failNextSignIn;
    failNextSignIn = null;
    await _start(FakeAuthOperation.signIn);
    if (failure != null) throw AuthFailure(failure);
    final account = directory.confirmedByEmail(normalizeEmail(email));
    if (account != null && directory.passwordOf(account) == password) {
      _signedIn = account;
      expireSession = false;
      return;
    }
    throw const AuthFailure(AuthFailureCode.signInFailed);
  }

  @override
  Future<void> signUp({
    required String email,
    required String displayName,
    required String password,
  }) async {
    await _start(FakeAuthOperation.signUp);
    final normalized = normalizeEmail(email);
    if (directory.isTaken(normalized)) {
      throw const AuthFailure(AuthFailureCode.emailInUse);
    }
    if (!meetsPasswordRule(password)) {
      throw const AuthFailure(AuthFailureCode.passwordRuleFailed);
    }
    directory.register(
      email: normalized,
      displayName: displayName.trim(),
      password: password,
    );
    _confirmationCodes[normalized] = _issueCode();
  }

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    await _start(FakeAuthOperation.confirmSignUp);
    final normalized = normalizeEmail(email);
    if (directory.unconfirmedByEmail(normalized) == null ||
        _confirmationCodes[normalized] != normalizeCode(code)) {
      throw const AuthFailure(AuthFailureCode.codeInvalidOrExpired);
    }
    _confirmationCodes.remove(normalized);
    directory.confirm(normalized);
  }

  @override
  Future<void> resendConfirmationCode({required String email}) async {
    await _start(FakeAuthOperation.resendCode);
    final normalized = normalizeEmail(email);
    // Unknown and confirmed addresses get the same silent acknowledgement.
    if (directory.unconfirmedByEmail(normalized) != null) {
      _confirmationCodes[normalized] = _issueCode();
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _start(FakeAuthOperation.requestReset);
    final normalized = normalizeEmail(email);
    if (directory.confirmedByEmail(normalized) != null) {
      _resetCodes[normalized] = _issueCode();
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _start(FakeAuthOperation.confirmReset);
    final normalized = normalizeEmail(email);
    final account = directory.confirmedByEmail(normalized);
    if (account == null || _resetCodes[normalized] != normalizeCode(code)) {
      throw const AuthFailure(AuthFailureCode.codeInvalidOrExpired);
    }
    if (!meetsPasswordRule(newPassword)) {
      throw const AuthFailure(AuthFailureCode.passwordRuleFailed);
    }
    _resetCodes.remove(normalized);
    directory.setPassword(account, newPassword);
  }

  @override
  Future<bool> hasSession() async => _signedIn != null;

  @override
  Future<String?> currentAccountId() async => _signedIn?.sub;

  @override
  Future<String?> accessToken() async {
    tokenCalls++;
    if (expireSession) {
      _signedIn = null;
      return null;
    }
    return _signedIn?.token;
  }

  @override
  Future<void> signOut() async => _signedIn = null;
}

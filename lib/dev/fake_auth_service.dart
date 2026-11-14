import '../auth/auth_service.dart';
import 'fake_accounts.dart';

/// A sign-in service for tests and the offline preview. It follows the C3
/// client behavior: one SIGN_IN_FAILED for every wrong credential.
final class FakeAuthService implements AuthService {
  FakeAuthService({this._accounts = fakeAccounts});

  final List<FakeAccount> _accounts;
  FakeAccount? _signedIn;

  /// When set, the next sign-in fails with this code.
  AuthFailureCode? failNextSignIn;

  /// When true, [accessToken] reports that the session has expired.
  bool expireSession = false;

  /// Delay before sign-in answers, to observe the loading state.
  Duration signInDelay = Duration.zero;

  int signInCalls = 0;

  FakeAccount? get signedInAccount => _signedIn;

  void signInAs(FakeAccount account) => _signedIn = account;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    if (signInDelay > Duration.zero) await Future<void>.delayed(signInDelay);
    final failure = failNextSignIn;
    if (failure != null) {
      failNextSignIn = null;
      throw AuthFailure(failure);
    }
    final normalized = normalizeEmail(email);
    for (final account in _accounts) {
      if (account.email == normalized && account.password == password) {
        _signedIn = account;
        expireSession = false;
        return;
      }
    }
    throw const AuthFailure(AuthFailureCode.signInFailed);
  }

  @override
  Future<bool> hasSession() async => _signedIn != null;

  @override
  Future<String?> accessToken() async {
    if (expireSession) {
      _signedIn = null;
      return null;
    }
    return _signedIn?.token;
  }

  @override
  Future<void> signOut() async => _signedIn = null;
}

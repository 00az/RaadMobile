/// Accounts that exist only in the local contract fake. They are fixtures for
/// tests, the integration journeys and the offline preview, not real users,
/// and they never reach a deployed environment.
library;

final class FakeAccount {
  const FakeAccount({
    required this.sub,
    required this.email,
    required this.displayName,
    required this.password,
  });

  final String sub;
  final String email;
  final String displayName;

  /// The password the account starts with; see [FakeDirectory.passwordOf].
  final String password;

  /// The bearer token the fake sign-in issues and the fake API accepts.
  String get token => 'fake-access.$sub';
}

const fakeSara = FakeAccount(
  sub: '7c0e8f1a-0000-4000-8000-000000000001',
  email: 'sara@raad.test',
  displayName: 'Sara Ali',
  password: 'Local-preview-1',
);

const fakeOmar = FakeAccount(
  sub: '7c0e8f1a-0000-4000-8000-000000000002',
  email: 'omar@raad.test',
  displayName: 'Omar Saleh',
  password: 'Local-preview-2',
);

const fakeAccounts = [fakeSara, fakeOmar];

/// The confirmed and unconfirmed accounts the fake sign-in knows, shared with
/// the fake Money API so a new sign-up can open a wallet.
final class FakeDirectory {
  FakeDirectory([Iterable<FakeAccount> confirmed = fakeAccounts])
    : _confirmed = [...confirmed];

  final List<FakeAccount> _confirmed;
  final Map<String, FakeAccount> _unconfirmed = {};
  final Map<String, String> _passwords = {};
  int _nextSub = 100;

  List<FakeAccount> get confirmed => List.unmodifiable(_confirmed);

  FakeAccount? confirmedByEmail(String normalizedEmail) {
    for (final account in _confirmed) {
      if (account.email == normalizedEmail) return account;
    }
    return null;
  }

  FakeAccount? unconfirmedByEmail(String normalizedEmail) =>
      _unconfirmed[normalizedEmail];

  FakeAccount? byToken(String token) {
    for (final account in _confirmed) {
      if (account.token == token) return account;
    }
    return null;
  }

  bool isTaken(String normalizedEmail) =>
      confirmedByEmail(normalizedEmail) != null ||
      _unconfirmed.containsKey(normalizedEmail);

  /// Adds an unconfirmed account, as sign-up does.
  FakeAccount register({
    required String email,
    required String displayName,
    required String password,
  }) {
    final account = FakeAccount(
      sub:
          '7c0e8f1a-0000-4000-8000-${(_nextSub++).toString().padLeft(12, '0')}',
      email: email,
      displayName: displayName,
      password: password,
    );
    _unconfirmed[email] = account;
    return account;
  }

  /// Moves an account from unconfirmed to confirmed.
  void confirm(String normalizedEmail) {
    final account = _unconfirmed.remove(normalizedEmail);
    if (account != null) _confirmed.add(account);
  }

  String passwordOf(FakeAccount account) =>
      _passwords[account.sub] ?? account.password;

  void setPassword(FakeAccount account, String password) =>
      _passwords[account.sub] = password;
}

/// Accounts that exist only in the local contract fake. They are fixtures for
/// tests and the offline preview, not real users, and they never reach a
/// deployed environment.
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

/// Where the app keeps its tokens. Tokens live only in the phone's secure
/// storage (Keychain on iOS, Keystore-backed storage on Android) and are
/// never logged.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class StoredSession {
  const StoredSession({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> save(StoredSession session);
  Future<void> clear();
}

final class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'raad.session.accessToken';
  static const _refreshKey = 'raad.session.refreshToken';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return StoredSession(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> save(StoredSession session) async {
    await _storage.write(key: _accessKey, value: session.accessToken);
    await _storage.write(key: _refreshKey, value: session.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Keeps the session in memory only; used by tests and the local preview.
final class MemorySessionStore implements SessionStore {
  StoredSession? _session;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> save(StoredSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

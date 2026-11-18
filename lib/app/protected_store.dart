/// Protected key-value storage for small private records: the pending
/// transfer, the last balance and the time of last use. On a phone it is the
/// Keychain (iOS) or Keystore-backed storage (Android). Nothing stored here is
/// ever logged.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ProtectedStore {
  Future<String?> read(String key);

  /// Throws when the value could not be stored; callers that must not go on
  /// without it (a transfer about to be sent) stop there.
  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class SecureProtectedStore implements ProtectedStore {
  SecureProtectedStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keeps values in memory only; used by tests and the offline preview.
class MemoryProtectedStore implements ProtectedStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

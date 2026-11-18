/// The last balance the Money API confirmed for one account in one
/// environment, with the time it was read (US2.2, BR3.5).
///
/// When a refresh fails or the phone is offline, the wallet shows this with
/// an out-of-date label and its time. With no snapshot it shows an error,
/// never a zero. It is kept in protected storage so a restart without a
/// connection still has it, and explicit sign-out removes it.
library;

import 'dart:convert';

import '../app/protected_store.dart';

final class BalanceSnapshot {
  const BalanceSnapshot({required this.halalas, required this.updatedAt});

  /// Whole halalas, exactly as the Money API returned them.
  final int halalas;

  /// When the Money API returned it, in UTC.
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'v': 1,
    'halalas': halalas,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static BalanceSnapshot? fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['v'] != 1) return null;
    final halalas = json['halalas'];
    final updatedAt = DateTime.tryParse('${json['updatedAt']}');
    if (halalas is! int || halalas < 0 || updatedAt == null) return null;
    return BalanceSnapshot(halalas: halalas, updatedAt: updatedAt.toUtc());
  }
}

final class BalanceSnapshotStore {
  const BalanceSnapshotStore(this._store);

  final ProtectedStore _store;

  static String keyFor({required String owner, required String environment}) =>
      'raad.balance.$environment.$owner';

  Future<BalanceSnapshot?> load({
    required String owner,
    required String environment,
  }) async {
    try {
      final raw = await _store.read(
        keyFor(owner: owner, environment: environment),
      );
      return raw == null ? null : BalanceSnapshot.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  Future<void> save({
    required String owner,
    required String environment,
    required BalanceSnapshot snapshot,
  }) async {
    try {
      await _store.write(
        keyFor(owner: owner, environment: environment),
        jsonEncode(snapshot.toJson()),
      );
    } on Object {
      // The screen still shows the fresh balance; only the offline copy is
      // missing.
    }
  }

  Future<void> clear({
    required String owner,
    required String environment,
  }) async {
    try {
      await _store.delete(keyFor(owner: owner, environment: environment));
    } on Object {
      // Nothing more can be done here.
    }
  }
}

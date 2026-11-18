/// The one transfer intent a person has confirmed but whose outcome the app
/// does not know yet (BR3.4, NFR4.10).
///
/// It is written to protected storage before the first send, so a crash, a
/// restart or signing in again as the same person brings it back without
/// sending anything. It is scoped to one account and one environment: another
/// account never sees it. Explicit sign-out removes it.
library;

import 'dart:convert';

import '../app/protected_store.dart';

enum PendingStatus {
  /// Saved, and the request may have left the phone.
  sending,

  /// The request was sent and no definite answer came back.
  uncertain,
}

final class PendingTransfer {
  const PendingTransfer({
    required this.requestKey,
    required this.owner,
    required this.environment,
    required this.recipientEmail,
    required this.recipientName,
    required this.recipientDisplayEmail,
    required this.amountHalalas,
    required this.balanceBeforeHalalas,
    required this.createdAt,
    required this.status,
  });

  /// The `Idempotency-Key` of this intent. It never changes and is never
  /// sent with other details.
  final String requestKey;

  /// The verified account (`sub`) that confirmed it.
  final String owner;
  final String environment;

  /// The normalized address that was looked up and sent.
  final String recipientEmail;
  final String recipientName;
  final String recipientDisplayEmail;
  final int amountHalalas;

  /// The balance shown on the review screen, for the projected balance.
  final int balanceBeforeHalalas;
  final DateTime createdAt;
  final PendingStatus status;

  PendingTransfer withStatus(PendingStatus status) => PendingTransfer(
    requestKey: requestKey,
    owner: owner,
    environment: environment,
    recipientEmail: recipientEmail,
    recipientName: recipientName,
    recipientDisplayEmail: recipientDisplayEmail,
    amountHalalas: amountHalalas,
    balanceBeforeHalalas: balanceBeforeHalalas,
    createdAt: createdAt,
    status: status,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'requestKey': requestKey,
    'owner': owner,
    'environment': environment,
    'recipientEmail': recipientEmail,
    'recipientName': recipientName,
    'recipientDisplayEmail': recipientDisplayEmail,
    'amountHalalas': amountHalalas,
    'balanceBeforeHalalas': balanceBeforeHalalas,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'status': status.name,
  };

  /// Reads a stored record, or null when it is not one this version wrote.
  static PendingTransfer? fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['v'] != 1) return null;
    final key = json['requestKey'];
    final owner = json['owner'];
    final environment = json['environment'];
    final email = json['recipientEmail'];
    final name = json['recipientName'];
    final displayEmail = json['recipientDisplayEmail'];
    final amount = json['amountHalalas'];
    final before = json['balanceBeforeHalalas'];
    final created = DateTime.tryParse('${json['createdAt']}');
    final status = PendingStatus.values.asNameMap()[json['status']];
    if (key is! String ||
        owner is! String ||
        environment is! String ||
        email is! String ||
        name is! String ||
        displayEmail is! String ||
        amount is! int ||
        before is! int ||
        created == null ||
        status == null) {
      return null;
    }
    return PendingTransfer(
      requestKey: key,
      owner: owner,
      environment: environment,
      recipientEmail: email,
      recipientName: name,
      recipientDisplayEmail: displayEmail,
      amountHalalas: amount,
      balanceBeforeHalalas: before,
      createdAt: created.toUtc(),
      status: status,
    );
  }
}

/// The pending transfer could not be saved, so it must not be sent.
final class PendingTransferNotSaved implements Exception {
  const PendingTransferNotSaved();

  @override
  String toString() => 'PendingTransferNotSaved';
}

final class PendingTransferStore {
  const PendingTransferStore(this._store);

  final ProtectedStore _store;

  static String keyFor({required String owner, required String environment}) =>
      'raad.pending.$environment.$owner';

  /// The unresolved intent of [owner] in [environment], if there is one.
  Future<PendingTransfer?> load({
    required String owner,
    required String environment,
  }) async {
    final String? raw;
    try {
      raw = await _store.read(keyFor(owner: owner, environment: environment));
    } on Object {
      return null;
    }
    if (raw == null) return null;
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    final record = PendingTransfer.fromJson(json);
    // A record is only ever handed back to the account and environment that
    // wrote it.
    if (record == null ||
        record.owner != owner ||
        record.environment != environment) {
      return null;
    }
    return record;
  }

  /// Throws [PendingTransferNotSaved] when protected storage refuses it.
  Future<void> save(PendingTransfer record) async {
    try {
      await _store.write(
        keyFor(owner: record.owner, environment: record.environment),
        jsonEncode(record.toJson()),
      );
    } on Object {
      throw const PendingTransferNotSaved();
    }
  }

  Future<void> clear({
    required String owner,
    required String environment,
  }) async {
    try {
      await _store.delete(keyFor(owner: owner, environment: environment));
    } on Object {
      // Nothing more can be done; a stale record is only ever shown, never
      // sent, and the server replays its first outcome.
    }
  }
}

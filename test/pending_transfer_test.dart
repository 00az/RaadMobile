// The pending transfer in protected storage: written before the first send,
// readable only by the account and environment that wrote it (BR3.4).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/money/pending_transfer.dart';

import 'support/fakes.dart';

PendingTransfer record({
  String owner = 'sara-sub',
  String environment = 'dev',
  PendingStatus status = PendingStatus.sending,
}) => PendingTransfer(
  requestKey: '0b6a5d2e-0000-4000-8000-000000000001',
  owner: owner,
  environment: environment,
  recipientEmail: 'omar@raad.test',
  recipientName: 'Omar Saleh',
  recipientDisplayEmail: 'omar@raad.test',
  amountHalalas: 10000,
  balanceBeforeHalalas: 100000,
  createdAt: DateTime.utc(2026, 11, 17, 9),
  status: status,
);

void main() {
  late FlakyStore storage;
  late PendingTransferStore store;

  setUp(() {
    storage = FlakyStore();
    store = PendingTransferStore(storage);
  });

  test('saves and restores every field, amounts as whole halalas', () async {
    await store.save(record(status: PendingStatus.uncertain));
    final restored = await store.load(owner: 'sara-sub', environment: 'dev');
    expect(restored, isNotNull);
    expect(
      restored!.toJson(),
      record(status: PendingStatus.uncertain).toJson(),
    );
    expect(restored.amountHalalas, isA<int>());
  });

  test('is kept per account and per environment', () async {
    await store.save(record());
    expect(await store.load(owner: 'omar-sub', environment: 'dev'), isNull);
    expect(await store.load(owner: 'sara-sub', environment: 'stg'), isNull);
    expect(
      storage.writtenKeys.single,
      PendingTransferStore.keyFor(owner: 'sara-sub', environment: 'dev'),
    );
  });

  test(
    'ignores a record stored under one account but naming another',
    () async {
      storage.values[PendingTransferStore.keyFor(
        owner: 'omar-sub',
        environment: 'dev',
      )] = jsonEncode(
        record().toJson(),
      );
      expect(await store.load(owner: 'omar-sub', environment: 'dev'), isNull);
    },
  );

  test('ignores an unreadable or older record', () async {
    final key = PendingTransferStore.keyFor(
      owner: 'sara-sub',
      environment: 'dev',
    );
    storage.values[key] = 'not json';
    expect(await store.load(owner: 'sara-sub', environment: 'dev'), isNull);
    storage.values[key] = jsonEncode({...record().toJson(), 'v': 0});
    expect(await store.load(owner: 'sara-sub', environment: 'dev'), isNull);
    storage.values[key] = jsonEncode({
      ...record().toJson(),
      'amountHalalas': 100.5,
    });
    expect(await store.load(owner: 'sara-sub', environment: 'dev'), isNull);
  });

  test('a refused write is reported, so the transfer is not sent', () async {
    storage.failWrites = true;
    await expectLater(
      store.save(record()),
      throwsA(isA<PendingTransferNotSaved>()),
    );
  });

  test('clear removes only that account\'s record', () async {
    await store.save(record());
    await store.save(record(owner: 'omar-sub'));
    await store.clear(owner: 'sara-sub', environment: 'dev');
    expect(await store.load(owner: 'sara-sub', environment: 'dev'), isNull);
    expect(await store.load(owner: 'omar-sub', environment: 'dev'), isNotNull);
  });
}

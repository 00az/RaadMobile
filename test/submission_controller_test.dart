// The submission controller over the generated client and the U2 contract
// fake: one key per confirmed intent, saved before sending, reused only by
// the person's Try again (US3.6, US3.8, BR3.4, NFR4.10).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/api/money_service.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/pending_transfer.dart';
import 'package:raad_mobile/money/submission_controller.dart';

import 'support/fakes.dart';

const transfers = 'POST /transfers';

const toOmar = ReviewedTransfer(
  recipientEmail: 'omar@raad.test',
  recipientName: 'Omar Saleh',
  recipientDisplayEmail: 'omar@raad.test',
  amountHalalas: 10000,
  balanceHalalas: 100000,
);

final class Rig {
  Rig() {
    auth.signInAs(fakeSara);
    backend
      ..openWallet(fakeSara)
      ..openWallet(fakeOmar);
    money = MoneyService.create(
      baseUrl: FakeMoneyBackend.baseUrl,
      auth: auth,
      adapter: backend,
      retryDelay: (_) async {},
    );
  }

  final FakeAuthService auth = FakeAuthService();
  final FakeMoneyBackend backend = FakeMoneyBackend();
  final FlakyStore storage = FlakyStore();
  late final MoneyService money;
  late final PendingTransferStore pending = PendingTransferStore(storage);

  SubmissionController controller() => SubmissionController(
    money: money,
    pending: pending,
    owner: fakeSara.sub,
    environment: 'dev',
  );

  Future<PendingTransfer?> saved() =>
      pending.load(owner: fakeSara.sub, environment: 'dev');

  List<String?> keysSent() => [
    for (final r in backend.requests)
      if (r.operation == transfers) r.idempotencyKey,
  ];
}

void main() {
  late Rig rig;

  setUp(() => rig = Rig());

  test('review then cancel sends nothing', () {
    final c = rig.controller()..review(toOmar);
    expect(c.state, SubmissionState.review);
    expect(c.requestKey, isNull, reason: 'the key is made at Confirm');
    c.cancel();
    expect(c.state, SubmissionState.draft);
    expect(rig.backend.countOf(transfers), 0);
  });

  test('saves the key before sending, then completes and forgets it', () async {
    final gate = Completer<void>();
    rig.backend.transferGate = gate;
    final c = rig.controller()..review(toOmar);

    final sending = c.confirm();
    await pumpEventQueue();
    expect(c.state, SubmissionState.submitting);
    final record = await rig.saved();
    expect(record, isNotNull);
    expect(record!.requestKey, rig.keysSent().single);
    expect(record.amountHalalas, 10000);
    expect(record.recipientEmail, 'omar@raad.test');

    gate.complete();
    await sending;
    expect(c.state, SubmissionState.completed);
    expect(c.result!.balanceAfter.amountHalalas, 90000);
    expect(await rig.saved(), isNull);
  });

  test('a pending record that cannot be saved blocks the send', () async {
    rig.storage.failWrites = true;
    final c = rig.controller()..review(toOmar);
    await c.confirm();
    expect(c.state, SubmissionState.review);
    expect(c.notice, SubmissionNotice.notSaved);
    expect(rig.backend.countOf(transfers), 0);
  });

  test('a double tap sends one request', () async {
    final c = rig.controller()..review(toOmar);
    await Future.wait([c.confirm(), c.confirm(), c.confirm()]);
    expect(rig.backend.countOf(transfers), 1);
    expect(rig.backend.balanceOf(fakeSara), 90000);
  });

  test(
    'a definite refusal keeps the values; the next attempt has a new key',
    () async {
      rig.backend.setBalance(fakeSara, 5000);
      final c = rig.controller()..review(toOmar);
      await c.confirm();
      expect(c.state, SubmissionState.businessRefused);
      expect(c.refusal!.code, 'INSUFFICIENT_FUNDS');
      expect(c.reviewed!.amountHalalas, 10000);
      expect(await rig.saved(), isNull);

      rig.backend.setBalance(fakeSara, 100000);
      c.review(toOmar);
      await c.confirm();
      expect(c.state, SubmissionState.completed);
      final keys = rig.keysSent();
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(2), reason: 'a new intent, a new key');
    },
  );

  test('after a lost answer, Try again resends exactly the saved key and '
      'details, and money moves once', () async {
    rig.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);
    final c = rig.controller()..review(toOmar);
    await c.confirm();
    expect(c.state, SubmissionState.uncertain);
    expect((await rig.saved())!.status, PendingStatus.uncertain);

    await c.tryAgain();
    expect(c.state, SubmissionState.completed);
    final sent = rig.backend.requests.where((r) => r.operation == transfers);
    expect(sent.map((r) => r.idempotencyKey).toSet(), hasLength(1));
    expect(sent.map((r) => jsonEncode(r.body)).toSet(), hasLength(1));
    expect(rig.backend.transfersBetween(fakeSara, fakeOmar), 1);
    expect(rig.backend.balanceOf(fakeSara), 90000);
    expect(await rig.saved(), isNull);
  });

  test(
    'repeated ambiguity keeps the intent uncertain with the same key',
    () async {
      final c = rig.controller()..review(toOmar);
      rig.backend.failNext(transfers, FakeFault.timeout);
      await c.confirm();
      rig.backend.failNext(transfers, FakeFault.serverError);
      await c.tryAgain();
      expect(c.state, SubmissionState.uncertain);
      expect(rig.keysSent().toSet(), hasLength(1));
      expect(rig.backend.balanceOf(fakeSara), 100000);
    },
  );

  test('Try again is only possible from the uncertain state', () async {
    final c = rig.controller()..review(toOmar);
    await c.tryAgain();
    expect(rig.backend.countOf(transfers), 0);
  });

  test('changing the details drops the old key; the next Confirm makes a '
      'new one', () async {
    rig.backend.failNext(transfers, FakeFault.timeout);
    final c = rig.controller()..review(toOmar);
    await c.confirm();
    final oldKey = c.requestKey;

    await c.changeDetails();
    expect(c.state, SubmissionState.draft);
    expect(c.checkHistoryFirst, isTrue);
    expect(await rig.saved(), isNull);

    c.historyChecked();
    expect(c.checkHistoryFirst, isFalse);
    c.review(toOmar);
    await c.confirm();
    expect(c.state, SubmissionState.completed);
    expect(rig.keysSent().last, isNot(oldKey));
  });

  group('restart and process death', () {
    test('before the send: the restored intent waits for Try again', () async {
      final record = PendingTransfer(
        requestKey: '0b6a5d2e-0000-4000-8000-0000000000aa',
        owner: fakeSara.sub,
        environment: 'dev',
        recipientEmail: 'omar@raad.test',
        recipientName: 'Omar Saleh',
        recipientDisplayEmail: 'omar@raad.test',
        amountHalalas: 2500,
        balanceBeforeHalalas: 100000,
        createdAt: DateTime.utc(2026, 11, 17),
        status: PendingStatus.sending,
      );
      await rig.pending.save(record);

      final restored = SubmissionController.restore(
        (await rig.saved())!,
        money: rig.money,
        pending: rig.pending,
      );
      expect(restored.state, SubmissionState.uncertain);
      expect(restored.requestKey, record.requestKey);
      expect(rig.backend.countOf(transfers), 0, reason: 'nothing automatic');

      await restored.tryAgain();
      expect(restored.state, SubmissionState.completed);
      expect(rig.keysSent(), [record.requestKey]);
      expect(rig.backend.balanceOf(fakeSara), 97500);
    });

    test(
      'after a possible commit: Try again returns the first result',
      () async {
        rig.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);
        final first = rig.controller()..review(toOmar);
        await first.confirm();
        expect(rig.backend.balanceOf(fakeSara), 90000, reason: 'it committed');

        // The app is killed here and opened again.
        final restored = SubmissionController.restore(
          (await rig.saved())!,
          money: rig.money,
          pending: rig.pending,
        );
        expect(rig.backend.countOf(transfers), 1);
        await restored.tryAgain();
        expect(restored.state, SubmissionState.completed);
        expect(restored.result!.balanceAfter.amountHalalas, 90000);
        expect(rig.backend.transfersBetween(fakeSara, fakeOmar), 1);
        expect(rig.backend.balanceOf(fakeSara), 90000);
      },
    );

    test('after the response: there is nothing to restore', () async {
      final c = rig.controller()..review(toOmar);
      await c.confirm();
      expect(c.state, SubmissionState.completed);
      expect(await rig.saved(), isNull);
    });

    test('another account or environment never sees the intent', () async {
      rig.backend.failNext(transfers, FakeFault.timeout);
      await (rig.controller()..review(toOmar)).confirm();
      expect(await rig.saved(), isNotNull);
      expect(
        await rig.pending.load(owner: fakeOmar.sub, environment: 'dev'),
        isNull,
      );
      expect(
        await rig.pending.load(owner: fakeSara.sub, environment: 'prd'),
        isNull,
      );
    });
  });

  group('attempts the service did not process', () {
    test('a rate limit on Try again keeps the intent uncertain', () async {
      rig.backend.failNext(transfers, FakeFault.timeout);
      final c = rig.controller()..review(toOmar);
      await c.confirm();
      rig.backend.answerNext(
        transfers,
        429,
        'RATE_LIMITED',
        retryAfterSeconds: 30,
      );
      await c.tryAgain();
      expect(c.state, SubmissionState.uncertain);
      expect(c.notice, SubmissionNotice.rateLimited);
      expect(c.retryAfter, const Duration(seconds: 30));
      expect(await rig.saved(), isNotNull);
    });

    test(
      'a rate limit on the first Confirm settles it with no saved key',
      () async {
        rig.backend.answerNext(
          transfers,
          429,
          'RATE_LIMITED',
          retryAfterSeconds: 5,
        );
        final c = rig.controller()..review(toOmar);
        await c.confirm();
        expect(c.state, SubmissionState.businessRefused);
        expect(c.refusal!.isRateLimited, isTrue);
        expect(c.retryAfter, const Duration(seconds: 5));
        expect(await rig.saved(), isNull);
      },
    );

    test(
      'a missing wallet is set up and Confirm resends the same key',
      () async {
        rig.backend.forgetWallet(fakeSara);
        final c = rig.controller()..review(toOmar);
        await c.confirm();
        expect(c.state, SubmissionState.review);
        expect(c.notice, SubmissionNotice.walletReady);
        await c.confirm();
        expect(c.state, SubmissionState.completed);
        expect(rig.keysSent().toSet(), hasLength(1));
      },
    );

    test('an ended session before the first send saves nothing', () async {
      rig.auth.expireSession = true;
      final c = rig.controller()..review(toOmar);
      await c.confirm();
      expect(c.state, SubmissionState.businessRefused);
      expect(c.notice, SubmissionNotice.signInAgain);
      expect(rig.backend.countOf(transfers), 0);
      expect(await rig.saved(), isNull);
    });

    test('an ended session during Try again keeps the intent for the same '
        'account', () async {
      rig.backend.failNext(transfers, FakeFault.timeout);
      final c = rig.controller()..review(toOmar);
      await c.confirm();
      rig.auth.expireSession = true;
      await c.tryAgain();
      expect(c.state, SubmissionState.uncertain);
      expect(c.notice, SubmissionNotice.signInAgain);
      expect((await rig.saved())!.requestKey, c.requestKey);
    });
  });
}

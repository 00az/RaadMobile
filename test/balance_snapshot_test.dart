// The kept balance and the wallet controller: out-of-date label, no invented
// zero, newest answer wins, nothing written after sign-out (US2.2, BR3.5,
// NFR5.10, NFR9.10).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/app/app_services.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/balance_snapshot.dart';
import 'package:raad_mobile/money/wallet_controller.dart';

import 'support/fakes.dart';

const getWallet = 'GET /wallet';
const putWallet = 'PUT /wallet';

void main() {
  late FakeClock clock;
  late FlakyStore store;
  late FakeMoneyBackend backend;
  late AppServices services;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 11, 17, 9));
    store = FlakyStore();
    final directory = FakeDirectory();
    backend = FakeMoneyBackend(directory: directory, now: clock.call);
    services = AppServices.create(
      auth: FakeAuthService(directory: directory),
      moneyBaseUrl: FakeMoneyBackend.baseUrl,
      moneyAdapter: backend,
      environmentName: 'dev',
      store: store,
      connectivity: FakeConnectivity(),
      now: clock.call,
      retryDelay: (_) async {},
    );
    await services.session.signIn(
      email: fakeSara.email,
      password: fakeSara.password,
    );
  });

  WalletController controller() => WalletController(
    money: services.money,
    session: services.session,
    balances: services.balances,
    environment: 'dev',
    now: clock.call,
  );

  Future<BalanceSnapshot?> kept() =>
      services.balances.load(owner: fakeSara.sub, environment: 'dev');

  test('a snapshot round-trips as whole halalas and refuses decimals', () {
    final snapshot = BalanceSnapshot(halalas: 123456, updatedAt: clock());
    expect(
      BalanceSnapshot.fromJson(jsonDecode(jsonEncode(snapshot.toJson())))!
          .halalas,
      123456,
    );
    expect(
      BalanceSnapshot.fromJson({...snapshot.toJson(), 'halalas': 12.5}),
      isNull,
    );
    expect(
      BalanceSnapshot.fromJson({...snapshot.toJson(), 'halalas': -1}),
      isNull,
    );
  });

  test('set-up keeps the confirmed balance with its UTC time', () async {
    final wallet = controller();
    await wallet.start();
    expect(wallet.setup, WalletSetup.ready);
    expect(wallet.snapshot!.halalas, 100000);
    expect(wallet.isStale, isFalse);
    final saved = await kept();
    expect(saved!.halalas, 100000);
    expect(saved.updatedAt, clock());
    expect(saved.updatedAt.isUtc, isTrue);
    expect(backend.countOf(putWallet), 1);
  });

  test('a failed refresh keeps the snapshot and marks it out of date; a '
      'good one clears the mark', () async {
    final wallet = controller();
    await wallet.start();
    clock.advance(const Duration(minutes: 5));
    backend.failNext(getWallet, FakeFault.unavailable, times: 2);
    await wallet.refresh();
    expect(wallet.isStale, isTrue);
    expect(wallet.snapshot!.halalas, 100000);
    expect(wallet.snapshot!.updatedAt, DateTime.utc(2026, 11, 17, 9));
    expect(wallet.error, isNotNull);

    backend.setBalance(fakeSara, 77700);
    await wallet.refresh();
    expect(wallet.isStale, isFalse);
    expect(wallet.snapshot!.halalas, 77700);
    expect(wallet.snapshot!.updatedAt, clock());
  });

  test(
    'a restart with a kept balance refreshes it instead of setting up',
    () async {
      await controller().start();
      final restarted = controller();
      await restarted.start();
      expect(backend.countOf(putWallet), 1);
      expect(backend.countOf(getWallet), 1);
      expect(restarted.isStale, isFalse);
    },
  );

  test(
    'a restart without a connection shows the kept balance, out of date',
    () async {
      await controller().start();
      backend.failNext(getWallet, FakeFault.connectionLost, times: 2);
      final restarted = controller();
      await restarted.start();
      expect(restarted.setup, WalletSetup.ready);
      expect(restarted.snapshot!.halalas, 100000);
      expect(restarted.isStale, isTrue);
    },
  );

  test('with no kept balance a failure never shows a zero', () async {
    backend.failNext(putWallet, FakeFault.unavailable, times: 2);
    final wallet = controller();
    await wallet.start();
    expect(wallet.setup, WalletSetup.failed);
    expect(wallet.snapshot, isNull);
    expect(await kept(), isNull);
  });

  test('only the newest request may change the balance', () async {
    final wallet = controller();
    await wallet.start();
    final older = backend.hold(getWallet);
    final first = wallet.refresh();
    await pumpEventQueue();

    backend.setBalance(fakeSara, 77700);
    await wallet.refresh();
    expect(wallet.snapshot!.halalas, 77700);

    backend.setBalance(fakeSara, 55500);
    older.complete();
    await first;
    expect(wallet.snapshot!.halalas, 77700, reason: 'the older answer lost');
    expect((await kept())!.halalas, 77700);
  });

  test('an answer that arrives after sign-out is not kept', () async {
    final wallet = controller();
    await wallet.start();
    final late = backend.hold(getWallet);
    final refreshing = wallet.refresh();
    await pumpEventQueue();

    await services.session.signOut();
    expect(await kept(), isNull, reason: 'sign-out removed it');
    late.complete();
    await refreshing;
    expect(await kept(), isNull, reason: 'the late answer was dropped');
  });

  test('a completed transfer\'s balanceAfter is kept as confirmed', () async {
    final wallet = controller();
    await wallet.start();
    clock.advance(const Duration(minutes: 1));
    await wallet.acceptBalanceAfterTransfer(90000);
    expect(wallet.snapshot!.halalas, 90000);
    expect((await kept())!.updatedAt, clock());
  });

  test('balances are kept per account and per environment', () async {
    await controller().start();
    expect(
      await services.balances.load(owner: fakeOmar.sub, environment: 'dev'),
      isNull,
    );
    expect(
      await services.balances.load(owner: fakeSara.sub, environment: 'stg'),
      isNull,
    );
  });
}

// The history page chain against the U2 contract fake: exact cursor and
// page size, shared Load more, kept rows on failure, restart on an expired
// cursor, dropped late answers and a 1000-entry chain (US4.3, BR3.6,
// NFR7.10, NFR7.11).

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/app/app_services.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/history_controller.dart';

import 'support/fakes.dart';

const listTransfers = 'GET /transfers';

void main() {
  late FakeClock clock;
  late FakeMoneyBackend backend;
  late AppServices services;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 11, 17, 9));
    final directory = FakeDirectory();
    backend = FakeMoneyBackend(directory: directory, now: clock.call)
      ..openWallet(fakeSara)
      ..openWallet(fakeOmar);
    services = AppServices.create(
      auth: FakeAuthService(directory: directory),
      moneyBaseUrl: FakeMoneyBackend.baseUrl,
      moneyAdapter: backend,
      environmentName: 'dev',
      store: MemoryProtectedStore(),
      connectivity: FakeConnectivity(),
      now: clock.call,
      retryDelay: (_) async {},
    );
    await services.session.signIn(
      email: fakeSara.email,
      password: fakeSara.password,
    );
  });

  void seed(int count, {DateTime? from}) {
    final start = from ?? DateTime.utc(2026, 1, 1);
    for (var i = 0; i < count; i++) {
      backend.seedTransfer(
        sender: i.isEven ? fakeSara : fakeOmar,
        recipient: i.isEven ? fakeOmar : fakeSara,
        amountHalalas: 100 + i,
        completedAt: start.add(Duration(minutes: i)),
      );
    }
  }

  HistoryController controller({int pageSize = 20}) => HistoryController(
    money: services.money,
    session: services.session,
    pageSize: pageSize,
  );

  List<Map<String, String>> queries() => [
    for (final r in backend.requests)
      if (r.operation == listTransfers) r.query,
  ];

  test('each page sends the exact cursor of the one before and the same '
      'page size', () async {
    seed(45);
    final firstPage = await services.money.historyPage();
    backend.requests.clear();

    final history = controller();
    await history.refresh();
    expect(history.items, hasLength(20));
    expect(history.hasMore, isTrue);
    await history.loadMore();
    await history.loadMore();

    final sent = queries();
    expect(sent, hasLength(3));
    expect(sent[0], {'limit': '20'});
    expect(sent[1], {'limit': '20', 'cursor': firstPage.nextCursor});
    expect(sent[2]['limit'], '20');
    expect(sent[2]['cursor'], isNot(sent[1]['cursor']));
    expect(history.items, hasLength(45));
    expect(history.hasMore, isFalse, reason: 'only a null cursor ends it');
  });

  test('rows keep the order the service returned', () async {
    seed(30);
    final history = controller(pageSize: 7);
    await history.refresh();
    while (history.hasMore) {
      await history.loadMore();
    }
    final times = history.items.map((i) => i.completedAt).toList();
    final sorted = [...times]..sort((a, b) => b.compareTo(a));
    expect(times, sorted);
  });

  test('repeated Load more taps share one request', () async {
    seed(45);
    final history = controller();
    await history.refresh();
    final held = backend.hold(listTransfers);
    final taps = [history.loadMore(), history.loadMore(), history.loadMore()];
    await pumpEventQueue();
    expect(history.isLoadingMore, isTrue);
    held.complete();
    await Future.wait(taps);
    expect(queries(), hasLength(2));
    expect(history.items, hasLength(40));
  });

  test('a failed page keeps the rows and retries the same cursor', () async {
    seed(45);
    final history = controller();
    await history.refresh();
    backend.failNext(listTransfers, FakeFault.unavailable, times: 2);

    await history.loadMore();
    expect(history.pageError, isNotNull);
    expect(history.items, hasLength(20));
    expect(history.hasMore, isTrue, reason: 'never claims the list is done');

    await history.loadMore();
    final cursors = queries().skip(1).map((q) => q['cursor']).toSet();
    expect(cursors, hasLength(1), reason: 'the same cursor every time');
    expect(history.pageError, isNull);
    expect(history.items, hasLength(40));
  });

  test('an expired cursor restarts page one and says so', () async {
    seed(45);
    final history = controller();
    await history.refresh();
    final firstIds = history.items.map((i) => i.transferId).toList();
    clock.advance(FakeMoneyBackend.cursorLifetime);

    await history.loadMore();

    expect(history.restarted, isTrue);
    expect(history.items.map((i) => i.transferId), firstIds);
    expect(queries().last, {'limit': '20'});
  });

  test(
    'refresh starts a new chain and drops a late answer from the old one',
    () async {
      seed(45);
      final history = controller();
      await history.refresh();
      final held = backend.hold(listTransfers);
      final late = history.loadMore();
      await pumpEventQueue();

      await history.refresh();
      expect(history.items, hasLength(20));
      held.complete();
      await late;
      expect(history.items, hasLength(20), reason: 'the old page was dropped');
      final ids = history.items.map((i) => i.transferId);
      expect(ids.toSet(), hasLength(ids.length));
    },
  );

  test('a transfer made during paging never shifts the chain', () async {
    seed(45);
    final history = controller();
    await history.refresh();
    backend.seedTransfer(
      sender: fakeOmar,
      recipient: fakeSara,
      amountHalalas: 999,
      completedAt: DateTime.utc(2026, 11, 17, 8),
    );
    while (history.hasMore) {
      await history.loadMore();
    }
    final ids = history.items.map((i) => i.transferId).toList();
    expect(ids, hasLength(45));
    expect(ids.toSet(), hasLength(45));

    await history.refresh();
    expect(history.items.first.amount.amountHalalas, 999);
  });

  test('1000 entries arrive with no duplicate or skipped row and no '
      'duplicate request', () async {
    seed(1000);
    final history = controller();
    await history.refresh();
    while (history.hasMore) {
      await Future.wait([history.loadMore(), history.loadMore()]);
    }

    final ids = history.items.map((i) => i.transferId).toList();
    expect(ids, hasLength(1000));
    expect(ids.toSet(), hasLength(1000));
    final amounts = history.items.map((i) => i.amount.amountHalalas).toList();
    expect(amounts, [for (var i = 999; i >= 0; i--) 100 + i]);
    final sent = queries();
    expect(sent, hasLength(50));
    expect(sent.map((q) => q['cursor']).toSet(), hasLength(50));
    expect(sent.every((q) => q['limit'] == '20'), isTrue);
  });

  test('loading, empty and error are separate states', () async {
    final history = controller();
    final held = backend.hold(listTransfers);
    final loading = history.refresh();
    await pumpEventQueue();
    expect(history.status, HistoryStatus.loading);
    held.complete();
    await loading;
    expect(history.status, HistoryStatus.empty);

    backend.failNext(listTransfers, FakeFault.unavailable, times: 2);
    await history.refresh();
    expect(history.status, HistoryStatus.error);

    seed(3);
    await history.refresh();
    expect(history.status, HistoryStatus.loaded);
  });

  test('an answer after sign-out is dropped', () async {
    seed(5);
    final history = controller();
    final held = backend.hold(listTransfers);
    final loading = history.refresh();
    await pumpEventQueue();
    await services.session.signOut();
    held.complete();
    await loading;
    expect(history.items, isEmpty);
  });
}

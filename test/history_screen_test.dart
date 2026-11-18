import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:raad_mobile/api/generated/money_api_client.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/screens/history_list.dart';
import 'package:raad_mobile/screens/history_screen.dart';
import 'package:raad_mobile/ui/formatting.dart';

import 'support/harness.dart';

const listTransfers = 'GET /transfers';

TransferListItem item({
  required String id,
  String direction = 'sent',
  int amount = 10000,
  String completedAt = '2026-11-12T08:30:00Z',
  Map<String, Object?> extra = const {},
}) => TransferListItem.fromJson({
  'transferId': id,
  'reference': 'R-$id',
  'direction': direction,
  'otherParty': {'displayName': 'Omar Saleh', 'email': 'omar@raad.test'},
  'amount': {'amountHalalas': amount, 'currency': 'SAR'},
  'completedAt': completedAt,
  ...extra,
});

Future<Harness> openHistory(
  WidgetTester tester, {
  void Function(Harness harness)? seed,
}) async {
  final harness = Harness()..signedInAsSara();
  // History is opened from a wallet that set-up has already created.
  harness.backend.openWallet(fakeSara);
  seed?.call(harness);
  await harness.session.restore();
  await tester.pumpWidget(harness.screen(const HistoryScreen()));
  await tester.pumpAndSettle();
  return harness;
}

void seedMany(Harness harness, int count) {
  for (var i = 0; i < count; i++) {
    harness.backend.seedTransfer(
      sender: fakeOmar,
      recipient: fakeSara,
      amountHalalas: 100 + i,
      completedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
    );
  }
}

/// Scrolls the lazily built history until [key] is on screen.
Future<void> scrollTo(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    byKey(key),
    600,
    scrollable: find.descendant(
      of: byKey('history.list'),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a new account sees "no transfers yet", not an error', (
    tester,
  ) async {
    await openHistory(tester);
    expect(textOf(tester, 'history.empty'), en.historyEmpty);
    expect(byKey('history.error'), findsNothing);
  });

  testWidgets('a failed load shows an error with Try again, never the empty '
      'message (AC4.4.2)', (tester) async {
    final harness = await openHistory(
      tester,
      seed: (h) {
        seedMany(h, 2);
        h.backend.failNext(listTransfers, FakeFault.unavailable, times: 2);
      },
    );
    expect(textOf(tester, 'history.error'), en.historyError);
    expect(byKey('history.empty'), findsNothing);

    await tapKey(tester, 'history.retry');
    expect(find.textContaining('Omar Saleh'), findsNWidgets(2));
    expect(harness.backend.countOf(listTransfers), 3);
  });

  testWidgets('labels sent and received rows with name, email, signed amount, '
      'reference and local time', (tester) async {
    final sentAt = DateTime.utc(2026, 11, 11, 10);
    await openHistory(
      tester,
      seed: (h) => h.backend
        ..seedTransfer(
          sender: fakeSara,
          recipient: fakeOmar,
          amountHalalas: 10000,
          completedAt: sentAt,
          reference: 'R-SENT00000001',
        )
        ..seedTransfer(
          sender: fakeOmar,
          recipient: fakeSara,
          amountHalalas: 25000,
          completedAt: DateTime.utc(2026, 11, 12, 10),
        ),
    );

    expect(find.text(en.historySentTo('Omar Saleh')), findsOneWidget);
    expect(find.text(en.historyReceivedFrom('Omar Saleh')), findsOneWidget);
    expect(find.text('-100.00 SAR'), findsOneWidget);
    expect(find.text('+250.00 SAR'), findsOneWidget);
    expect(find.text('omar@raad.test'), findsNWidgets(2));
    final time = DateFormat('d MMM yyyy, HH:mm').format(sentAt.toLocal());
    expect(
      find.text('$time · ${en.historyReference('R-SENT00000001')}'),
      findsOneWidget,
    );
    // Newest first, as the service returned it.
    expect(
      tester.getTopLeft(find.text('+250.00 SAR')).dy,
      lessThan(tester.getTopLeft(find.text('-100.00 SAR')).dy),
    );
  });

  testWidgets('rows keep the order they arrive in; the app never re-sorts', (
    tester,
  ) async {
    final harness = Harness();
    await tester.pumpWidget(
      harness.screen(
        Scaffold(
          body: SingleChildScrollView(
            child: HistoryList(
              items: [
                item(id: 'b', completedAt: '2026-11-01T00:00:00Z'),
                item(id: 'a', completedAt: '2026-11-02T00:00:00Z'),
              ],
              loading: false,
              error: null,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(byKey('history.item.b')).dy,
      lessThan(tester.getTopLeft(byKey('history.item.a')).dy),
    );
  });

  testWidgets('Load more follows the cursor; the end shows no button', (
    tester,
  ) async {
    final harness = await openHistory(tester, seed: (h) => seedMany(h, 25));
    await scrollTo(tester, 'history.loadMore');
    await tester.tap(byKey('history.loadMore'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'history.end');

    expect(byKey('history.loadMore'), findsNothing);
    final sent = harness.backend.requests.where(
      (r) => r.operation == listTransfers,
    );
    expect(sent.last.query.keys, containsAll(['cursor', 'limit']));
  });

  testWidgets('a failed page keeps the rows and offers Try again for it', (
    tester,
  ) async {
    final harness = await openHistory(tester, seed: (h) => seedMany(h, 25));
    harness.backend.failNext(listTransfers, FakeFault.unavailable, times: 2);
    await scrollTo(tester, 'history.loadMore');
    await tester.tap(byKey('history.loadMore'));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'history.loadMoreError'), en.historyLoadMoreFailed);
    await tester.tap(byKey('history.loadMoreRetry'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'history.end');
    expect(byKey('history.loadMoreError'), findsNothing);
  });

  testWidgets('an expired cursor reloads page one with a message', (
    tester,
  ) async {
    final harness = await openHistory(tester, seed: (h) => seedMany(h, 25));
    harness.clock.advance(FakeMoneyBackend.cursorLifetime);
    await scrollTo(tester, 'history.loadMore');
    await tester.tap(byKey('history.loadMore'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      byKey('history.restarted'),
      -600,
      scrollable: find.descendant(
        of: byKey('history.list'),
        matching: find.byType(Scrollable),
      ),
    );
    expect(textOf(tester, 'history.restarted'), en.historyRestarted);
  });

  testWidgets('the Refresh button and pull to refresh start page one again', (
    tester,
  ) async {
    final harness = await openHistory(tester, seed: (h) => seedMany(h, 3));
    await tapKey(tester, 'history.refresh');
    await tester.fling(byKey('history.list'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    final sent = harness.backend.requests.where(
      (r) => r.operation == listTransfers,
    );
    expect(sent, hasLength(3));
    expect(sent.every((r) => !r.query.containsKey('cursor')), isTrue);
  });

  testWidgets('a 1000-entry history pages through with no duplicate request', (
    tester,
  ) async {
    final harness = await openHistory(tester, seed: (h) => seedMany(h, 1000));
    var pages = 1;
    while (byKey('history.end').evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (w) =>
              w.key == const ValueKey('history.loadMore') ||
              w.key == const ValueKey('history.end'),
        ),
        3000,
        scrollable: find.descendant(
          of: byKey('history.list'),
          matching: find.byType(Scrollable),
        ),
      );
      if (byKey('history.loadMore').evaluate().isEmpty) break;
      await tester.tap(byKey('history.loadMore'));
      await tester.tap(byKey('history.loadMore'), warnIfMissed: false);
      await tester.pumpAndSettle();
      pages++;
    }
    expect(pages, 50);
    final sent = harness.backend.requests
        .where((r) => r.operation == listTransfers)
        .toList();
    expect(sent, hasLength(50));
    expect(sent.map((r) => r.query['cursor']).toSet(), hasLength(50));
    // The oldest transfer is the last row.
    expect(find.text('+1.00 SAR'), findsOneWidget);
  });

  testWidgets('tolerates unknown fields and an unknown direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      Harness().screen(
        Scaffold(
          body: HistoryEntry(
            item: item(
              id: 'future',
              direction: 'reversed',
              extra: {'category': 'gift'},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Omar Saleh'), findsOneWidget);
    expect(find.text('100.00 SAR'), findsOneWidget);
  });

  group('local time of the UTC instant (AC4.1.5, NFR15.10)', () {
    setUpAll(() => initializeDateFormatting('ar'));

    final instant = DateTime.utc(2026, 11, 12, 20, 30);

    test('a transfer at 23:30 in Riyadh reads 23:30 there', () {
      expect(
        Formats.forLocalizations(en)
            .dateTimeAt(instant, const Duration(hours: 3)),
        '12 Nov 2026, 23:30',
      );
    });

    test('the same instant reads in another zone\'s own time', () {
      expect(
        Formats.forLocalizations(en)
            .dateTimeAt(instant, const Duration(hours: -5)),
        '12 Nov 2026, 15:30',
      );
    });

    test('Arabic keeps Western digits (A8)', () {
      final text = Formats.forLocalizations(ar)
          .dateTimeAt(instant, const Duration(hours: 3));
      expect(text, contains('23:30'));
      expect(text, contains('2026'));
      expect(RegExp('[٠-٩]').hasMatch(text), isFalse);
    });
  });
}

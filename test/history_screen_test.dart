import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:raad_mobile/api/generated/money_api_client.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/screens/history_list.dart';

import 'support/harness.dart';

Map<String, Object?> itemJson({
  required String id,
  String direction = 'sent',
  int amount = 10000,
  String completedAt = '2026-11-12T08:30:00Z',
}) => {
  'transferId': id,
  'reference': 'RD-$id',
  'direction': direction,
  'otherParty': {'displayName': 'Omar Saleh', 'email': 'omar@raad.test'},
  'amount': {'amountHalalas': amount, 'currency': 'SAR'},
  'completedAt': completedAt,
};

Widget historyOf(List<Map<String, Object?>> items, {String? nextCursor}) {
  final page = TransferPage.fromJson({
    'items': items,
    'nextCursor': nextCursor,
  });
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HistoryList(page: page, loading: false, error: null),
      ),
    ),
  );
}

void main() {
  testWidgets('shows an empty state with no transfers', (tester) async {
    await tester.pumpWidget(historyOf(const []));
    expect(byKey('history.empty'), findsOneWidget);
    expect(byKey('history.truncated'), findsNothing);
  });

  testWidgets('labels sent and received transfers and signs their amounts', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    harness.backend
      ..seedTransfer(
        sender: fakeSara,
        recipient: fakeOmar,
        amountHalalas: 10000,
        completedAt: DateTime.utc(2026, 11, 11, 10),
      )
      ..seedTransfer(
        sender: fakeOmar,
        recipient: fakeSara,
        amountHalalas: 25000,
        completedAt: DateTime.utc(2026, 11, 12, 10),
      );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    final sent = find.text('To Omar Saleh');
    final received = find.text('From Omar Saleh');
    expect(sent, findsOneWidget);
    expect(received, findsOneWidget);
    expect(find.text('-100.00 SAR'), findsOneWidget);
    expect(find.text('+250.00 SAR'), findsOneWidget);
    // Newest first.
    expect(
      tester.getTopLeft(received).dy,
      lessThan(tester.getTopLeft(sent).dy),
    );
  });

  testWidgets('orders by time, then by transfer ID, newest first', (
    tester,
  ) async {
    await tester.pumpWidget(
      historyOf([
        itemJson(
          id: '00000000-0000-4000-8000-00000000000a',
          completedAt: '2026-11-01T00:00:00Z',
        ),
        itemJson(
          id: '00000000-0000-4000-8000-00000000000b',
          completedAt: '2026-11-02T00:00:00Z',
        ),
        itemJson(
          id: '00000000-0000-4000-8000-00000000000c',
          completedAt: '2026-11-02T00:00:00Z',
        ),
      ]),
    );
    double top(String id) => tester.getTopLeft(byKey('history.item.$id')).dy;
    expect(
      top('00000000-0000-4000-8000-00000000000c'),
      lessThan(top('00000000-0000-4000-8000-00000000000b')),
    );
    expect(
      top('00000000-0000-4000-8000-00000000000b'),
      lessThan(top('00000000-0000-4000-8000-00000000000a')),
    );
  });

  testWidgets('shows completion time in the phone time zone', (tester) async {
    final instant = DateTime.utc(2026, 11, 12, 21, 45);
    await tester.pumpWidget(
      historyOf([
        itemJson(id: 'local-time', completedAt: '2026-11-12T21:45:00Z'),
      ]),
    );
    final expected = DateFormat('d MMM yyyy, HH:mm').format(instant.toLocal());
    expect(HistoryEntry.formatTime(instant), expected);
    expect(find.textContaining(expected), findsOneWidget);
    expect(find.textContaining('RD-local-time'), findsOneWidget);
  });

  testWidgets('says the list is partial when another page exists', (
    tester,
  ) async {
    final harness = Harness()..signedInAsSara();
    for (var i = 0; i < 25; i++) {
      harness.backend.seedTransfer(
        sender: fakeOmar,
        recipient: fakeSara,
        amountHalalas: 100,
        completedAt: DateTime.utc(2026, 11, 1).add(Duration(hours: i)),
      );
    }
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(byKey('history.truncated'), 200);
    expect(
      textOf(tester, 'history.truncated'),
      'Showing your latest 20 transfers.',
    );
    expect(
      harness.backend.requests.where((r) => r.path.contains('cursor')),
      isEmpty,
    );
    expect(harness.backend.countOf('GET /transfers'), 1);
  });

  testWidgets('a history error does not hide the balance', (tester) async {
    final harness = Harness()..signedInAsSara();
    harness.backend.failNext('GET /transfers', FakeFault.unavailable);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(byKey('history.error'), findsOneWidget);
    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
  });

  testWidgets('tolerates unknown fields and an unknown direction', (
    tester,
  ) async {
    final item = itemJson(id: 'future', direction: 'reversed')
      ..['category'] = 'gift';
    await tester.pumpWidget(historyOf([item]));
    expect(find.text('Omar Saleh'), findsOneWidget);
    expect(find.text('100.00 SAR'), findsOneWidget);
  });
}

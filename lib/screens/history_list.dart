import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/generated/money_api_client.dart';
import '../money/halalas.dart';

/// US4.1 and US4.2: the first page of completed sent and received transfers.
class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.page,
    required this.loading,
    required this.error,
  });

  final TransferPage? page;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading && page == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(key: ValueKey('history.loading')),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error!, key: const ValueKey('history.error')),
      );
    }
    final items = [...?page?.items]..sort(_newestFirst);
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No transfers yet.', key: ValueKey('history.empty')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) HistoryEntry(item: item),
        // U1 shows the first page only and does not claim it is complete.
        if (page?.nextCursor != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Showing your latest ${items.length} transfers.',
              key: const ValueKey('history.truncated'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  static int _newestFirst(TransferListItem a, TransferListItem b) {
    final byTime = b.completedAt.compareTo(a.completedAt);
    return byTime != 0 ? byTime : b.transferId.compareTo(a.transferId);
  }
}

class HistoryEntry extends StatelessWidget {
  const HistoryEntry({super.key, required this.item});

  final TransferListItem item;

  /// Completion time in the phone's own time zone (AC4.1.4).
  static String formatTime(DateTime instant) =>
      DateFormat('d MMM yyyy, HH:mm').format(instant.toLocal());

  @override
  Widget build(BuildContext context) {
    final direction = item.direction;
    final sent = direction == TransferListItemDirection.sent;
    final received = direction == TransferListItemDirection.received;
    final name = item.otherParty.displayName;
    final title = sent ? 'To $name' : (received ? 'From $name' : name);
    final amount = item.amount.amountHalalas;
    final amountText = sent
        ? formatHalalas(-amount)
        : (received
              ? formatHalalas(amount, signed: true)
              : formatHalalas(amount));
    return ListTile(
      key: ValueKey('history.item.${item.transferId}'),
      leading: Icon(sent ? Icons.north_east : Icons.south_west),
      title: Text(title),
      subtitle: Text('${formatTime(item.completedAt)} · ${item.reference}'),
      trailing: Text(
        amountText,
        key: ValueKey('history.amount.${item.transferId}'),
      ),
    );
  }
}

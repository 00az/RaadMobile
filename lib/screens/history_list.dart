import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/generated/money_api_client.dart';
import '../money/halalas.dart';
import '../ui/raad_theme.dart';

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
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(
            key: ValueKey('history.loading'),
            color: RaadColors.cyanAccent,
          ),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RaadColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RaadColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: RaadColors.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error!,
                  key: const ValueKey('history.error'),
                  style: const TextStyle(color: RaadColors.error, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final items = [...?page?.items]..sort(_newestFirst);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: RaadColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RaadColors.cardBorder),
          ),
          child: const Center(
            child: Text(
              'No transfers yet.',
              key: ValueKey('history.empty'),
              style: TextStyle(color: RaadColors.textSecondary, fontSize: 14),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) HistoryEntry(item: item),
        // U1 shows the first page only and does not claim it is complete. The
        // U1 service reports left-out rows with hasMore and keeps nextCursor
        // null; a U2 service sets nextCursor.
        if (page?.hasMore == true || page?.nextCursor != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Showing your latest ${items.length} transfers.',
              key: const ValueKey('history.truncated'),
              style: const TextStyle(
                color: RaadColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
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

    final badgeColor = received
        ? RaadColors.success
        : (sent ? RaadColors.textSecondary : RaadColors.cyanAccent);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: RaadColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RaadColors.cardBorder),
      ),
      child: ListTile(
        key: ValueKey('history.item.${item.transferId}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Icon(
            sent ? Icons.north_east : Icons.south_west,
            color: badgeColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: RaadColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${formatTime(item.completedAt)} · ${item.reference}',
            style: const TextStyle(color: RaadColors.textMuted, fontSize: 12),
          ),
        ),
        trailing: Text(
          amountText,
          key: ValueKey('history.amount.${item.transferId}'),
          style: TextStyle(
            color: received ? RaadColors.success : RaadColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

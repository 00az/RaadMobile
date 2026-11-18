import 'package:flutter/material.dart';

import '../api/generated/money_api_client.dart';
import '../l10n/app_localizations.dart';
import '../ui/formatting.dart';
import '../ui/raad_theme.dart';
import '../widgets/status_banner.dart';

/// The wallet's latest transfers (S6): loading, error with Try again, empty
/// and loaded views kept apart (US4.4, US5.3). Rows keep the order the Money
/// API returned them in.
class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    this.onRetry,
  });

  final List<TransferListItem>? items;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = items;
    if (loading && rows == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Semantics(
            label: l10n.loading,
            liveRegion: true,
            child: const CircularProgressIndicator(
              key: ValueKey('history.loading'),
              color: RaadColors.cyanAccent,
            ),
          ),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: StatusBanner(
          kind: StatusKind.error,
          text: '${l10n.historyError} $error',
          textKey: const ValueKey('history.error'),
          action: onRetry == null
              ? null
              : TextButton(
                  key: const ValueKey('history.retry'),
                  onPressed: onRetry,
                  child: Text(l10n.tryAgain),
                ),
        ),
      );
    }
    if (rows == null || rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: RaadColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RaadColors.cardBorder),
          ),
          child: Center(
            child: Text(
              l10n.historyEmpty,
              key: const ValueKey('history.empty'),
              style: const TextStyle(
                color: RaadColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final item in rows) HistoryEntry(item: item)],
    );
  }
}

/// One sent or received transfer (TransferListItem in the interaction
/// spec). Direction shows as an arrow, words and a sign, never colour alone.
class HistoryEntry extends StatelessWidget {
  const HistoryEntry({super.key, required this.item});

  final TransferListItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formats = Formats.of(context);
    final sent = item.direction == TransferListItemDirection.sent;
    final received = item.direction == TransferListItemDirection.received;
    final name = item.otherParty.displayName;
    // A direction this version does not know shows the name alone.
    final title = sent
        ? l10n.historySentTo(name)
        : (received ? l10n.historyReceivedFrom(name) : name);
    final halalas = item.amount.amountHalalas;
    final amountText = sent
        ? formats.money(-halalas)
        : formats.money(halalas, signed: received);
    final time = formats.dateTime(item.completedAt);
    final email = formats.ltr(item.otherParty.email);
    final reference = formats.ltr(item.reference);
    final badgeColor = received
        ? RaadColors.success
        : (sent ? RaadColors.textSecondary : RaadColors.cyanAccent);
    final amount = Text(
      amountText,
      key: ValueKey('history.amount.${item.transferId}'),
      style: TextStyle(
        color: received ? RaadColors.success : RaadColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
    // With large text the amount gets its own line instead of squeezing
    // the name; it stays one unit either way.
    final largeText = MediaQuery.textScalerOf(context).scale(15) > 20;

    return Semantics(
      key: ValueKey('history.item.${item.transferId}'),
      container: true,
      label: l10n.historyEntrySemantics(
        title,
        email,
        amountText,
        time,
        reference,
      ),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: RaadColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RaadColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: RaadColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      color: RaadColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$time · ${l10n.historyReference(reference)}',
                    style: const TextStyle(
                      color: RaadColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (largeText) ...[const SizedBox(height: 4), amount],
                ],
              ),
            ),
            if (!largeText) ...[const SizedBox(width: 8), amount],
          ],
        ),
      ),
    );
  }
}

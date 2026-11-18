import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../l10n/app_localizations.dart';
import '../money/history_controller.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import '../widgets/status_banner.dart';
import 'history_list.dart';

/// S10, the full history (US4.1 to US4.4, US5.3).
///
/// Page one loads on opening and on Refresh (a button, or pull to refresh);
/// Load more follows the opaque cursor one page at a time. The list is built
/// lazily, so a long history keeps a bounded number of rows on screen.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.pageSize});

  /// C1's default when null.
  final int? pageSize;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryController? _controller;

  HistoryController get _history => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final services = AppServices.of(context);
    _controller = HistoryController(
      money: services.money,
      session: services.session,
      pageSize: widget.pageSize ?? 20,
    )..addListener(_onHistory);
    _history.refresh();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _history.status;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletHistory),
        actions: [
          const EnvironmentChip(),
          IconButton(
            key: const ValueKey('history.refresh'),
            tooltip: l10n.refresh,
            icon: const Icon(Icons.sync_rounded),
            onPressed: _history.refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          key: const ValueKey('history.pullToRefresh'),
          onRefresh: _history.refresh,
          color: RaadColors.cyanAccent,
          child: switch (status) {
            HistoryStatus.loading => _message(
              Semantics(
                label: l10n.loading,
                liveRegion: true,
                child: const CircularProgressIndicator(
                  key: ValueKey('history.loading'),
                  color: RaadColors.cyanAccent,
                ),
              ),
            ),
            HistoryStatus.error => _message(
              StatusBanner(
                kind: StatusKind.error,
                text: l10n.historyError,
                textKey: const ValueKey('history.error'),
                action: TextButton(
                  key: const ValueKey('history.retry'),
                  onPressed: _history.refresh,
                  child: Text(l10n.tryAgain),
                ),
              ),
            ),
            HistoryStatus.empty => _message(
              Text(
                l10n.historyEmpty,
                key: const ValueKey('history.empty'),
                style: const TextStyle(color: RaadColors.textSecondary),
              ),
            ),
            HistoryStatus.loaded => _list(l10n),
          },
        ),
      ),
    );
  }

  /// One centred view that can still be pulled to refresh.
  Widget _message(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Center(child: child),
      ],
    );
  }

  Widget _list(AppLocalizations l10n) {
    final items = _history.items;
    final header = <Widget>[
      if (_history.restarted)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: StatusBanner(
            kind: StatusKind.info,
            text: l10n.historyRestarted,
            textKey: const ValueKey('history.restarted'),
          ),
        ),
      if (_history.error case final error?)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: StatusBanner(
            kind: StatusKind.error,
            text: '${l10n.historyError} ${Messages.forMoneyError(l10n, error)}',
            textKey: const ValueKey('history.refreshError'),
            action: TextButton(
              key: const ValueKey('history.retry'),
              onPressed: _history.refresh,
              child: Text(l10n.tryAgain),
            ),
          ),
        ),
    ];
    return ListView.builder(
      key: const ValueKey('history.list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: header.length + items.length + 1,
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        final row = index - header.length;
        if (row < items.length) return HistoryEntry(item: items[row]);
        return _footer(l10n);
      },
    );
  }

  /// Load more, its spinner, its failure, or nothing at the end.
  Widget _footer(AppLocalizations l10n) {
    final Widget child;
    if (_history.isLoadingMore) {
      child = Semantics(
        label: l10n.loading,
        liveRegion: true,
        child: const CircularProgressIndicator(
          key: ValueKey('history.loadingMore'),
          color: RaadColors.cyanAccent,
        ),
      );
    } else if (_history.pageError != null) {
      child = StatusBanner(
        kind: StatusKind.error,
        text: l10n.historyLoadMoreFailed,
        textKey: const ValueKey('history.loadMoreError'),
        action: TextButton(
          key: const ValueKey('history.loadMoreRetry'),
          onPressed: _history.loadMore,
          child: Text(l10n.tryAgain),
        ),
      );
    } else if (_history.hasMore) {
      child = OutlinedButton(
        key: const ValueKey('history.loadMore'),
        onPressed: _history.loadMore,
        child: Text(l10n.historyLoadMore),
      );
    } else {
      child = Text(
        l10n.historyEnd,
        key: const ValueKey('history.end'),
        style: const TextStyle(color: RaadColors.textSecondary, fontSize: 12),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: child),
    );
  }
}

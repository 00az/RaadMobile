/// The history's page chain (US4.2 to US4.4, US5.3; BR3.6; NFR7.10).
///
/// - Page one starts a chain; each later page passes the exact opaque
///   `nextCursor` of the page before it with the same page size, and rows
///   are kept in the order the Money API returns them.
/// - Repeated Load more taps share one request.
/// - A failed page keeps every row and retries the same cursor; it never
///   says the list is complete. Only a null cursor ends the list.
/// - An invalid or expired cursor restarts page one and says so.
/// - Refresh replaces the chain; answers that arrive late for the old chain
///   are dropped, as are answers from a session that has ended.
/// - Nothing loads by itself: no polling, no push.
library;

import 'package:flutter/foundation.dart';

import '../api/generated/money_api_client.dart';
import '../api/money_service.dart';
import '../auth/session_boundary.dart';

enum HistoryStatus { loading, empty, error, loaded }

class HistoryController extends ChangeNotifier {
  HistoryController({
    required this._money,
    required this._session,
    this.pageSize = MoneyService.defaultPageSize,
  });

  final MoneyService _money;
  final SessionBoundary _session;
  final int pageSize;

  final List<TransferListItem> _items = [];
  String? _cursor;
  bool _firstLoading = false;
  bool _loadedOnce = false;
  MoneyApiException? _firstError;
  MoneyApiException? _pageError;
  bool _restarted = false;
  int _chain = 0;
  Future<void>? _loadingMore;
  bool _disposed = false;

  List<TransferListItem> get items => List.unmodifiable(_items);

  /// True while another page exists in this chain.
  bool get hasMore => _cursor != null;

  bool get isLoadingMore => _loadingMore != null;

  /// The failure of the last Load more; the rows stay.
  MoneyApiException? get pageError => _pageError;

  /// The failure of the last page-one request.
  MoneyApiException? get error => _firstError;

  /// The chain was started again because its cursor was no longer valid.
  bool get restarted => _restarted;

  HistoryStatus get status {
    if (_firstLoading && !_loadedOnce) return HistoryStatus.loading;
    if (_firstError != null && _items.isEmpty) return HistoryStatus.error;
    if (_items.isEmpty) {
      return _loadedOnce ? HistoryStatus.empty : HistoryStatus.loading;
    }
    return HistoryStatus.loaded;
  }

  /// Page one, starting a new chain. Answers for the old chain are dropped.
  Future<void> refresh({bool restarted = false}) async {
    final chain = ++_chain;
    _loadingMore = null;
    _firstLoading = true;
    _firstError = null;
    _pageError = null;
    _restarted = restarted;
    _changed();
    try {
      final page = await _session.whileCurrent(
        () => _money.historyPage(limit: pageSize),
      );
      if (page == null || !_current(chain)) return;
      _items
        ..clear()
        ..addAll(page.items);
      _cursor = page.nextCursor;
      _loadedOnce = true;
    } on MoneyApiException catch (error) {
      if (!_current(chain)) return;
      if (error.isAuthenticationRequired) {
        await _session.expire();
        return;
      }
      _firstError = error;
    }
    _firstLoading = false;
    _changed();
  }

  /// The next page of this chain. A second tap while one is loading gets
  /// the same request.
  Future<void> loadMore() {
    final running = _loadingMore;
    if (running != null) return running;
    if (_cursor == null) return Future.value();
    late final Future<void> loading;
    loading = _loadMore(_chain, _cursor!).whenComplete(() {
      if (identical(_loadingMore, loading)) _loadingMore = null;
      _changed();
    });
    _loadingMore = loading;
    _pageError = null;
    _changed();
    return loading;
  }

  Future<void> _loadMore(int chain, String cursor) async {
    try {
      final page = await _session.whileCurrent(
        () => _money.historyPage(cursor: cursor, limit: pageSize),
      );
      if (page == null || !_current(chain)) return;
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _restarted = false;
    } on MoneyApiException catch (error) {
      if (!_current(chain)) return;
      if (error.isAuthenticationRequired) {
        await _session.expire();
        return;
      }
      if (error.code == MoneyErrorCode.cursorInvalidOrExpired) {
        _loadingMore = null;
        await refresh(restarted: true);
        return;
      }
      // Keep the rows and the cursor: Try again asks for the same page.
      _pageError = error;
    }
  }

  bool _current(int chain) => !_disposed && chain == _chain;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

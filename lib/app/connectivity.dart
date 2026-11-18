/// Whether the phone looks connected. The signal is advisory only: a request
/// can still fail while it says online, so a transfer that fails in transport
/// still ends in the uncertain state. Offline turns off Send, Confirm and
/// Try again; nothing is ever queued (US3.9, BR3.5).
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract class ConnectivitySignal extends ChangeNotifier {
  bool get isOnline;
}

/// The phone's own network state, through `connectivity_plus`.
final class PlatformConnectivitySignal extends ConnectivitySignal {
  PlatformConnectivitySignal([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(
      _apply,
      // A platform that cannot report its state is treated as online; the
      // request itself then decides.
      onError: (Object _) => _set(true),
    );
    unawaited(
      _connectivity.checkConnectivity().then(_apply, onError: (Object _) {}),
    );
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _online = true;

  @override
  bool get isOnline => _online;

  void _apply(List<ConnectivityResult> results) =>
      _set(results.any((result) => result != ConnectivityResult.none));

  void _set(bool online) {
    if (online == _online) return;
    _online = online;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// A signal set by hand, for tests, integration journeys and the offline
/// preview.
final class ManualConnectivitySignal extends ConnectivitySignal {
  ManualConnectivitySignal({this._online = true});

  bool _online;

  @override
  bool get isOnline => _online;

  set online(bool value) {
    if (value == _online) return;
    _online = value;
    notifyListeners();
  }
}

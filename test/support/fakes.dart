// Small controllable stand-ins for time, the network signal and protected
// storage. No test touches the real clock, network state or Keychain.

import 'package:raad_mobile/app/connectivity.dart';
import 'package:raad_mobile/app/protected_store.dart';

export 'package:raad_mobile/app/connectivity.dart'
    show ManualConnectivitySignal;
export 'package:raad_mobile/app/protected_store.dart' show MemoryProtectedStore;

/// A clock the test moves by hand. Pass [call] where the app takes a
/// `DateTime Function()`.
final class FakeClock {
  FakeClock([DateTime? start])
    : current = (start ?? DateTime.utc(2026, 11, 17, 9)).toUtc();

  DateTime current;

  DateTime call() => current;

  void advance(Duration by) => current = current.add(by);

  void set(DateTime to) => current = to.toUtc();
}

/// Protected storage that can be told to refuse writes, to show that a
/// transfer is never sent when its pending record could not be saved.
final class FlakyStore extends MemoryProtectedStore {
  bool failWrites = false;
  final List<String> writtenKeys = [];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('protected storage refused the write');
    writtenKeys.add(key);
    await super.write(key, value);
  }
}

/// A network signal the test switches with `online = false` and back.
typedef FakeConnectivity = ManualConnectivitySignal;

/// Typed as the app's interfaces, so a fake that drifts from them stops
/// compiling.
final ConnectivitySignal Function() fakeConnectivity = FakeConnectivity.new;
final ProtectedStore Function() fakeStore = FlakyStore.new;

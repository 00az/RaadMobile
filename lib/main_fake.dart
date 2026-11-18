import 'package:flutter/material.dart';

import 'app/app_services.dart';
import 'app/connectivity.dart';
import 'app/protected_store.dart';
import 'app/raad_app.dart';
import 'dev/fake_accounts.dart';
import 'dev/fake_auth_service.dart';
import 'dev/fake_money_backend.dart';

/// An offline preview against the local contract fake; no network is used.
///
///     flutter run -t lib/main_fake.dart
///
/// Sign in as sara@raad.test with Local-preview-1 and send to omar@raad.test.
/// This entry point is never used for a store or tester build.
void main() {
  final directory = FakeDirectory();
  runApp(
    RaadApp(
      services: AppServices.create(
        auth: FakeAuthService(directory: directory),
        moneyBaseUrl: FakeMoneyBackend.baseUrl,
        moneyAdapter: FakeMoneyBackend.preview(directory: directory),
        environmentName: 'local',
        environmentChip: 'LOCAL',
        store: MemoryProtectedStore(),
        // The fake answers without a network, so the preview stays online.
        connectivity: ManualConnectivitySignal(),
        demoShortcuts: true,
      ),
    ),
  );
}

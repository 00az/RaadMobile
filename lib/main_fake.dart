import 'package:flutter/material.dart';

import 'api/money_service.dart';
import 'app/app_services.dart';
import 'app/raad_app.dart';
import 'dev/fake_auth_service.dart';
import 'dev/fake_money_backend.dart';

/// An offline preview against the local contract fake; no network is used.
///
///     flutter run -t lib/main_fake.dart
///
/// Sign in as sara@raad.test with Local-preview-1 and send to omar@raad.test.
/// This entry point is never used for a store or tester build.
void main() {
  final auth = FakeAuthService();
  final money = MoneyService.create(
    baseUrl: FakeMoneyBackend.baseUrl,
    auth: auth,
    adapter: FakeMoneyBackend.preview(),
  );
  runApp(
    RaadApp(
      services: AppServices(auth: auth, money: money, environmentChip: 'LOCAL'),
    ),
  );
}

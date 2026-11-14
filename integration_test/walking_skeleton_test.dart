// U1 walking skeleton on a simulator or emulator: sign in, see the balance,
// review and send 100 SAR, see the result, then see the transfer in both
// people's history.
//
// Against the contract fake (default, no network):
//   flutter test integration_test
//
// Against dev, once Engineer 1 hands over the C4 values and two fresh funded
// test accounts. The values come from a temporary define file that the
// verification script writes from Secrets Manager and deletes afterwards;
// never put passwords on the command line or in the repo:
//   flutter test integration_test --dart-define-from-file=<c4-config.json> \
//     --dart-define-from-file=<temporary-e2e-accounts.json>
// with RAAD_E2E_TARGET=dev, RAAD_E2E_SENDER_EMAIL, RAAD_E2E_SENDER_PASSWORD,
// RAAD_E2E_RECIPIENT_EMAIL and RAAD_E2E_RECIPIENT_PASSWORD in the second file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raad_mobile/api/money_service.dart';
import 'package:raad_mobile/app/app_services.dart';
import 'package:raad_mobile/app/raad_app.dart';
import 'package:raad_mobile/auth/cognito_auth_service.dart';
import 'package:raad_mobile/auth/session_store.dart';
import 'package:raad_mobile/config/environment_config.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/halalas.dart';

const target = String.fromEnvironment('RAAD_E2E_TARGET', defaultValue: 'fake');

final class Account {
  const Account(this.email, this.password);

  final String email;
  final String password;
}

Future<(AppServices, Account, Account)> setUpTarget() async {
  if (target == 'dev') {
    final config = EnvironmentConfig.fromDartDefines();
    if (config.environment != RaadEnvironment.dev) {
      throw StateError('The walking skeleton runs against dev only.');
    }
    const sender = Account(
      String.fromEnvironment('RAAD_E2E_SENDER_EMAIL'),
      String.fromEnvironment('RAAD_E2E_SENDER_PASSWORD'),
    );
    const recipient = Account(
      String.fromEnvironment('RAAD_E2E_RECIPIENT_EMAIL'),
      String.fromEnvironment('RAAD_E2E_RECIPIENT_PASSWORD'),
    );
    for (final value in [
      sender.email,
      sender.password,
      recipient.email,
      recipient.password,
    ]) {
      if (value.isEmpty) {
        throw StateError('A dev test account value is missing.');
      }
    }
    final store = SecureSessionStore();
    await store.clear();
    final auth = CognitoAuthService(config: config, store: store);
    final money = MoneyService.create(
      baseUrl: config.moneyApiBaseUrl,
      auth: auth,
    );
    return (
      AppServices(
        auth: auth,
        money: money,
        environmentChip: config.environment.chipLabel,
      ),
      sender,
      recipient,
    );
  }
  final auth = FakeAuthService();
  final backend = FakeMoneyBackend()..openWallet(fakeOmar);
  final money = MoneyService.create(
    baseUrl: FakeMoneyBackend.baseUrl,
    auth: auth,
    adapter: backend,
  );
  return (
    AppServices(auth: auth, money: money, environmentChip: 'LOCAL'),
    Account(fakeSara.email, fakeSara.password),
    Account(fakeOmar.email, fakeOmar.password),
  );
}

Finder byKey(String key) => find.byKey(ValueKey(key));

/// Pumps until [finder] shows, for real network latency on dev.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pump();
}

Future<void> signIn(WidgetTester tester, Account account) async {
  await waitFor(tester, byKey('signIn.submit'));
  await tester.enterText(byKey('signIn.email'), account.email);
  await tester.enterText(byKey('signIn.password'), account.password);
  await tapKey(tester, 'signIn.submit');
  await waitFor(tester, byKey('wallet.balance'));
}

int balanceShown(WidgetTester tester) {
  final text = textOf(tester, 'wallet.balance').replaceAll(' SAR', '');
  return parseSarToHalalas(text) ?? 0;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'walking skeleton: balance, one 100 SAR transfer, both histories',
    (tester) async {
      final (services, sender, recipient) = await setUpTarget();
      await tester.pumpWidget(RaadApp(services: services));

      // The sender signs in and sees their SAR balance.
      await signIn(tester, sender);
      final before = balanceShown(tester);
      expect(before, greaterThanOrEqualTo(10000));

      // They enter the recipient and amount, then review before sending.
      await tapKey(tester, 'wallet.send');
      await waitFor(tester, byKey('send.email'));
      await tester.enterText(byKey('send.email'), recipient.email);
      await tester.enterText(byKey('send.amount'), '100');
      await tapKey(tester, 'send.continue');
      await waitFor(tester, byKey('review.confirm'));
      expect(textOf(tester, 'review.email'), recipient.email.toLowerCase());
      expect(textOf(tester, 'review.amount'), '100.00 SAR');
      expect(
        textOf(tester, 'review.projectedBalance'),
        formatHalalas(before - 10000),
      );
      final recipientName = textOf(tester, 'review.name');

      // They confirm once and see the reference and new balance.
      await tapKey(tester, 'review.confirm');
      await waitFor(tester, byKey('result.reference'));
      final reference = textOf(tester, 'result.reference');
      expect(reference, isNotEmpty);
      expect(textOf(tester, 'result.balance'), formatHalalas(before - 10000));

      // Back on the wallet, the balance and the sent entry agree.
      await tapKey(tester, 'result.done');
      await waitFor(tester, find.textContaining(reference));
      expect(balanceShown(tester), before - 10000);
      expect(find.text('To $recipientName'), findsWidgets);

      // The recipient signs in and sees the same transfer as received.
      await tapKey(tester, 'wallet.signOut');
      await signIn(tester, recipient);
      await waitFor(tester, find.textContaining(reference));
      final entry = find.ancestor(
        of: find.textContaining(reference),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: entry, matching: find.textContaining('From ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: entry, matching: find.text('+100.00 SAR')),
        findsOneWidget,
      );
    },
  );
}

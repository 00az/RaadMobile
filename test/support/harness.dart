import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/api/money_service.dart';
import 'package:raad_mobile/app/app_services.dart';
import 'package:raad_mobile/app/raad_app.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';

/// The app on top of the generated C1 client, wired to the contract fake.
final class Harness {
  Harness({DateTime Function()? now})
    : backend = FakeMoneyBackend(now: now),
      auth = FakeAuthService() {
    money = MoneyService.create(
      baseUrl: FakeMoneyBackend.baseUrl,
      auth: auth,
      adapter: backend,
    );
  }

  final FakeMoneyBackend backend;
  final FakeAuthService auth;
  late final MoneyService money;

  AppServices get services =>
      AppServices(auth: auth, money: money, environmentChip: 'DEV');

  /// Sara is signed in and Omar already has a wallet she can send to.
  Harness signedInAsSara() {
    auth.signInAs(fakeSara);
    backend.openWallet(fakeOmar);
    return this;
  }

  Widget app() => RaadApp(services: services);

  /// One widget inside the app's services, without the sign-in gate.
  Widget screen(Widget child) => AppScope(
    services: services,
    child: MaterialApp(home: child),
  );
}

Finder byKey(String key) => find.byKey(ValueKey(key));

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(byKey(key), text);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

/// Opens the send form from the wallet and fills it in.
Future<void> fillSendForm(
  WidgetTester tester, {
  required String email,
  required String amount,
}) async {
  await tapKey(tester, 'wallet.send');
  await enter(tester, 'send.email', email);
  await enter(tester, 'send.amount', amount);
}

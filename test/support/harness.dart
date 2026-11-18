import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/api/money_service.dart';
import 'package:raad_mobile/app/app_services.dart';
import 'package:raad_mobile/app/language.dart';
import 'package:raad_mobile/app/raad_app.dart';
import 'package:raad_mobile/auth/session_boundary.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/l10n/app_localizations.dart';

import 'fakes.dart';

/// The app on top of the generated C1 client, wired to the contract fakes
/// exactly as `AppServices.create` wires the real app.
final class Harness {
  Harness({FakeClock? clock})
    : clock = clock ?? FakeClock(),
      directory = FakeDirectory() {
    backend = FakeMoneyBackend(directory: directory, now: this.clock.call);
    auth = FakeAuthService(directory: directory);
    services = AppServices.create(
      auth: auth,
      moneyBaseUrl: FakeMoneyBackend.baseUrl,
      moneyAdapter: backend,
      environmentName: 'dev',
      environmentChip: 'DEV',
      store: store,
      connectivity: connectivity,
      now: this.clock.call,
      retryDelay: (_) async {},
    );
  }

  final FakeClock clock;
  final FakeDirectory directory;
  final FlakyStore store = FlakyStore();
  final FakeConnectivity connectivity = FakeConnectivity();
  late final FakeMoneyBackend backend;
  late final FakeAuthService auth;
  late final AppServices services;

  MoneyService get money => services.money;
  SessionBoundary get session => services.session;
  LanguageSetting get language => services.language;

  /// Sara is signed in (used the app just now) and Omar already has a
  /// wallet she can send to.
  Harness signedInAsSara() => signedInAs(fakeSara);

  Harness signedInAs(FakeAccount account) {
    auth.signInAs(account);
    store.values[SessionBoundary.lastUseKey] = clock()
        .toUtc()
        .toIso8601String();
    backend.openWallet(fakeOmar);
    return this;
  }

  Widget app() => RaadApp(services: services);

  /// One widget inside the app's services, without the sign-in gate.
  Widget screen(Widget child, {Locale locale = const Locale('en')}) => AppScope(
    services: services,
    child: MaterialApp(
      locale: locale,
      supportedLocales: LanguageSetting.supportedLocales,
      localizationsDelegates: raadLocalizationsDelegates,
      home: child,
    ),
  );
}

/// English text, for tests that compare what the screen says.
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

/// Arabic text.
final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

Finder byKey(String key) => find.byKey(ValueKey(key));

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(byKey(key), text);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await showKey(tester, key);
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

/// Brings [key] on screen, scrolling a lazily built list until it exists.
Future<void> showKey(WidgetTester tester, String key) async {
  final finder = byKey(key);
  if (finder.evaluate().isEmpty) {
    // The visible page's own list comes first in tree order; the text
    // fields' inner scrollables come after it, and covered routes are not
    // hit-testable.
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
  }
  await tester.ensureVisible(finder);
  // Lay out the jumped list before anyone reads the widget's position.
  await tester.pump();
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

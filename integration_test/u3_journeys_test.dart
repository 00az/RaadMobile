// U3 journeys on a simulator or emulator, FAKE-BACKED: they run the real app
// against the local contract fakes of the Money API (C1, U2 rules) and of
// sign-in (C3), with no network and no AWS. They are not evidence about a
// deployed environment; the live journeys against dev wait for the dev
// deploy.
//
//   flutter test integration_test/u3_journeys_test.dart -d <ios-simulator-id>
//   flutter test integration_test/u3_journeys_test.dart -d <android-emulator-id> \
//     --flavor dev

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raad_mobile/app/app_services.dart';
import 'package:raad_mobile/app/connectivity.dart';
import 'package:raad_mobile/app/protected_store.dart';
import 'package:raad_mobile/app/raad_app.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/l10n/app_localizations.dart';

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

/// The app on the fakes, with the handles a journey needs.
final class FakeWorld {
  FakeWorld() {
    backend = FakeMoneyBackend.preview(directory: directory);
    auth = FakeAuthService(directory: directory);
    services = AppServices.create(
      auth: auth,
      moneyBaseUrl: FakeMoneyBackend.baseUrl,
      moneyAdapter: backend,
      environmentName: 'local',
      environmentChip: 'LOCAL',
      store: MemoryProtectedStore(),
      connectivity: connectivity,
      retryDelay: (_) async {},
    );
  }

  final FakeDirectory directory = FakeDirectory();
  final ManualConnectivitySignal connectivity = ManualConnectivitySignal();
  late final FakeMoneyBackend backend;
  late final FakeAuthService auth;
  late final AppServices services;

  List<String?> transferKeys() => [
    for (final r in backend.requests)
      if (r.operation == 'POST /transfers') r.idempotencyKey,
  ];
}

Finder byKey(String key) => find.byKey(ValueKey(key));

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

/// Pumps until [finder] shows.
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Scrolls the visible page until [key] is built and on screen.
Future<void> show(WidgetTester tester, String key) async {
  if (byKey(key).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      byKey(key),
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
  }
  await tester.ensureVisible(byKey(key));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  await show(tester, key);
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await show(tester, key);
  await tester.enterText(
    find.descendant(
      of: byKey(key),
      matching: find.byType(EditableText),
      matchRoot: true,
    ),
    text,
  );
  await tester.pump();
  // Close the software keyboard, as a person does before the next step; on a
  // simulator it would otherwise cover the rest of the form.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String email, String password) async {
  await waitFor(tester, byKey('signIn.submit'));
  await type(tester, 'signIn.email', email);
  await type(tester, 'signIn.password', password);
  await tap(tester, 'signIn.submit');
  await waitFor(tester, byKey('wallet.balance'));
}

Future<void> sendToOmar(WidgetTester tester, String amount) async {
  await tap(tester, 'wallet.send');
  await type(tester, 'send.email', fakeOmar.email);
  await type(tester, 'send.amount', amount);
  await tap(tester, 'send.continue');
  await waitFor(tester, byKey('review.amount'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up, confirm, sign in, wallet, send, result and history', (
    tester,
  ) async {
    final world = FakeWorld();
    await tester.pumpWidget(RaadApp(services: world.services));
    await waitFor(tester, byKey('signIn.submit'));

    await tap(tester, 'signIn.signUp');
    await type(tester, 'signUp.name', 'Amal');
    await type(tester, 'signUp.email', 'amal@example.test');
    await type(tester, 'signUp.password', 'Abcdef12');
    await tap(tester, 'signUp.submit');

    await waitFor(tester, byKey('confirm.code'));
    await type(
      tester,
      'confirm.code',
      world.auth.confirmationCodeFor('amal@example.test')!,
    );
    await tap(tester, 'confirm.submit');
    await waitFor(tester, byKey('signIn.notice'));

    await type(tester, 'signIn.password', 'Abcdef12');
    await tap(tester, 'signIn.submit');
    await waitFor(tester, byKey('wallet.balance'));
    expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');

    await sendToOmar(tester, '25');
    expect(textOf(tester, 'review.projectedBalance'), '975.00 SAR');
    await tap(tester, 'review.confirm');
    await waitFor(tester, byKey('result.reference'));
    expect(textOf(tester, 'result.balance'), '975.00 SAR');

    await tap(tester, 'result.done');
    await waitFor(tester, find.text(en.historySentTo('Omar Saleh')));
    await tap(tester, 'wallet.seeAll');
    await waitFor(tester, find.text('-25.00 SAR'));
    expect(world.backend.balanceOf(fakeOmar), 102500);
  });

  testWidgets('a lost answer, then Try again with the same key: money moves '
      'once', (tester) async {
    final world = FakeWorld();
    await tester.pumpWidget(RaadApp(services: world.services));
    await signIn(tester, fakeSara.email, fakeSara.password);

    await sendToOmar(tester, '100');
    world.backend.failNext(
      'POST /transfers',
      FakeFault.lostResponseAfterCommit,
    );
    await tap(tester, 'review.confirm');
    await waitFor(tester, byKey('review.outcomeUnknown'));
    expect(world.backend.balanceOf(fakeSara), 90000, reason: 'it committed');

    await tap(tester, 'review.tryAgain');
    await waitFor(tester, byKey('result.reference'));
    expect(textOf(tester, 'result.balance'), '900.00 SAR');
    expect(world.transferKeys(), hasLength(2));
    expect(world.transferKeys().toSet(), hasLength(1));
    expect(world.backend.transfersBetween(fakeSara, fakeOmar), 1);
  });

  testWidgets('offline turns sending off with a reason, and back on', (
    tester,
  ) async {
    final world = FakeWorld();
    await tester.pumpWidget(RaadApp(services: world.services));
    await signIn(tester, fakeSara.email, fakeSara.password);

    world.connectivity.online = false;
    await tester.pumpAndSettle();
    expect(textOf(tester, 'wallet.sendOffline'), en.walletSendOffline);
    await tester.tap(byKey('wallet.send'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(byKey('send.continue'), findsNothing, reason: 'Send is off');

    world.connectivity.online = true;
    await tester.pumpAndSettle();
    expect(byKey('wallet.sendOffline'), findsNothing);
    await tap(tester, 'wallet.send');
    expect(byKey('send.continue'), findsOneWidget);
    expect(world.backend.countOf('POST /transfers'), 0, reason: 'no queue');
  });

  testWidgets('Arabic lays the app out right to left; switching back keeps '
      'the session', (tester) async {
    final world = FakeWorld();
    await tester.pumpWidget(RaadApp(services: world.services));
    await waitFor(tester, byKey('signIn.submit'));

    await tap(tester, 'app.language');
    expect(find.text(ar.signInTitle), findsWidgets);
    expect(
      Directionality.of(tester.element(byKey('signIn.submit'))),
      TextDirection.rtl,
    );

    await signIn(tester, fakeSara.email, fakeSara.password);
    expect(find.text(ar.walletTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(byKey('wallet.balance'))),
      TextDirection.rtl,
    );

    await tap(tester, 'wallet.account');
    await tap(tester, 'language.en');
    expect(find.text(en.accountTitle), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(en.walletTitle), findsOneWidget);
    expect(world.services.session.isActive, isTrue);
  });
}

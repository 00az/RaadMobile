// Accessibility checks that run in every pull request (US5.2, US5.3,
// BR3.7; accessibility checklist "How This Is Tested"): Flutter's guideline
// checks for tap targets, labelled targets and text contrast, 200% text at a
// 320 dp width with no clipped action, announced status changes, and the
// decorative parts announced as not available. VoiceOver and TalkBack
// walkthroughs on real devices are release evidence, not these tests.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/app/language.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/screens/history_screen.dart';

import 'support/display.dart';
import 'support/harness.dart';

Future<void> meetsAllGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Future<Harness> openApp(
  WidgetTester tester, {
  bool signedIn = true,
  AppLanguage language = AppLanguage.en,
}) async {
  final harness = Harness();
  if (signedIn) harness.signedInAsSara();
  // Omar can receive whether or not Sara starts signed in.
  harness.backend.openWallet(fakeOmar);
  harness.backend.seedTransfer(
    sender: fakeOmar,
    recipient: fakeSara,
    amountHalalas: 2500,
    completedAt: DateTime.utc(2026, 11, 10, 9),
  );
  await harness.language.choose(language);
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
  return harness;
}

/// True when some ancestor of [finder] announces changes as a live region.
bool announced(Finder finder) => find
    .ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
    )
    .evaluate()
    .isNotEmpty;

/// Shows [key] and checks that a tap there reaches it.
Future<void> expectReachable(WidgetTester tester, String key) async {
  await showKey(tester, key);
  expect(byKey(key).hitTestable(), findsOneWidget, reason: '$key clipped');
}

void main() {
  for (final language in AppLanguage.values) {
    group('guideline checks in ${language.name}', () {
      testWidgets('sign-in', (tester) async {
        final handle = tester.ensureSemantics();
        await openApp(tester, signedIn: false, language: language);
        await meetsAllGuidelines(tester);
        handle.dispose();
      });

      testWidgets('wallet', (tester) async {
        final handle = tester.ensureSemantics();
        await openApp(tester, language: language);
        await meetsAllGuidelines(tester);
        handle.dispose();
      });

      testWidgets('send, review and result', (tester) async {
        final handle = tester.ensureSemantics();
        await openApp(tester, language: language);
        await fillSendForm(tester, email: fakeOmar.email, amount: '100');
        await meetsAllGuidelines(tester);
        await tapKey(tester, 'send.continue');
        await meetsAllGuidelines(tester);
        await tapKey(tester, 'review.confirm');
        await meetsAllGuidelines(tester);
        handle.dispose();
      });

      testWidgets('history and account', (tester) async {
        final handle = tester.ensureSemantics();
        await openApp(tester, language: language);
        await tapKey(tester, 'wallet.seeAll');
        await meetsAllGuidelines(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tapKey(tester, 'wallet.account');
        await meetsAllGuidelines(tester);
        handle.dispose();
      });

      testWidgets('sign-up, confirmation and password reset', (tester) async {
        final handle = tester.ensureSemantics();
        await openApp(tester, signedIn: false, language: language);
        for (final link in [
          'signIn.signUp',
          'signIn.haveCode',
          'signIn.forgot',
        ]) {
          await tapKey(tester, link);
          await meetsAllGuidelines(tester);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        handle.dispose();
      });
    });
  }

  group('200% text at 320 dp (AC5.2.2)', () {
    for (final language in AppLanguage.values) {
      testWidgets('sign-in, wallet, send, review and history keep every '
          'action usable in ${language.name}', (tester) async {
        useSmallPhoneWithLargeText(tester);
        final harness = await openApp(
          tester,
          signedIn: false,
          language: language,
        );
        expect(tester.takeException(), isNull);
        // Type first: the list is built lazily, so the fields leave the tree
        // once the links further down are scrolled into view.
        await enter(tester, 'signIn.email', fakeSara.email);
        await enter(tester, 'signIn.password', fakeSara.password);
        await expectReachable(tester, 'signIn.haveCode');
        await expectReachable(tester, 'signIn.forgot');
        await expectReachable(tester, 'signIn.submit');
        await tester.tap(byKey('signIn.submit'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'wallet');
        for (final key in [
          'wallet.refresh',
          'wallet.balance',
          'wallet.send',
          'wallet.account',
          'wallet.seeAll',
        ]) {
          await expectReachable(tester, key);
        }

        await tapKey(tester, 'wallet.send');
        expect(tester.takeException(), isNull, reason: 'send');
        await enter(tester, 'send.email', fakeOmar.email);
        await enter(tester, 'send.amount', '100');
        await expectReachable(tester, 'send.max');
        await expectReachable(tester, 'send.continue');
        await tester.tap(byKey('send.continue'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'review');
        await expectReachable(tester, 'review.cancel');
        await expectReachable(tester, 'review.confirm');
        harness.backend.failNext('POST /transfers', FakeFault.timeout);
        await tester.tap(byKey('review.confirm'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'uncertain');
        // Top to bottom, as the screen reads.
        await expectReachable(tester, 'review.checkWallet');
        await expectReachable(tester, 'review.tryAgain');
        await expectReachable(tester, 'review.changeDetails');
        // From the uncertain view, Back goes to the wallet.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        await tapKey(tester, 'wallet.seeAll');
        expect(tester.takeException(), isNull, reason: 'history');
        await expectReachable(tester, 'history.refresh');
      });
    }
  });

  group('announced status, never colour alone (R2, P3)', () {
    testWidgets('out of date, refusals, sending and the unknown outcome', (
      tester,
    ) async {
      final harness = await openApp(tester);
      harness.backend.failNext('GET /wallet', FakeFault.connectionLost);
      await tapKey(tester, 'wallet.refresh');
      expect(announced(byKey('wallet.stale')), isTrue);
      expect(
        find.descendant(
          of: find.ancestor(
            of: byKey('wallet.stale'),
            matching: find.byType(Wrap),
          ),
          matching: find.byIcon(Icons.schedule_rounded),
        ),
        findsOneWidget,
      );

      await fillSendForm(tester, email: 'nobody@raad.test', amount: '100');
      await tapKey(tester, 'send.continue');
      harness.backend.answerNext(
        'POST /recipients/resolve',
        429,
        'RATE_LIMITED',
      );
      await tapKey(tester, 'send.continue');
      expect(announced(byKey('send.error')), isTrue);

      await enter(tester, 'send.email', fakeOmar.email);
      await tapKey(tester, 'send.continue');
      harness.backend.failNext('POST /transfers', FakeFault.timeout);
      await tapKey(tester, 'review.confirm');
      expect(announced(byKey('review.outcomeUnknown')), isTrue);
    });

    testWidgets('loading, empty and error views are announced', (tester) async {
      final harness = Harness()..signedInAsSara();
      harness.backend.openWallet(fakeSara);
      await harness.session.restore();
      harness.backend.failNext(
        'GET /transfers',
        FakeFault.unavailable,
        times: 2,
      );
      await tester.pumpWidget(harness.screen(const HistoryScreen()));
      await tester.pumpAndSettle();
      expect(announced(byKey('history.error')), isTrue);
    });

    testWidgets('sent and received differ by words, arrow and sign', (
      tester,
    ) async {
      await openApp(tester);
      expect(find.text(en.historyReceivedFrom('Omar Saleh')), findsOneWidget);
      expect(find.text('+25.00 SAR'), findsOneWidget);
      expect(find.byIcon(Icons.south_west), findsOneWidget);
    });
  });

  group('decorative parts', () {
    testWidgets('the card, Apple Wallet and the two other services are '
        'announced as not available', (tester) async {
      final handle = tester.ensureSemantics();
      await openApp(tester);
      expect(
        find.bySemanticsLabel('${en.cardsPreview}. ${en.notAvailableYet}'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '${en.cardsAddToAppleWallet}. ${en.notAvailableYet}',
        ),
        findsOneWidget,
      );
      for (final service in [
        en.walletServiceInternational,
        en.walletServiceBank,
      ]) {
        expect(
          find.bySemanticsLabel('$service. ${en.notAvailableYet}'),
          findsOneWidget,
        );
      }
      final international = tester.getSemantics(
        byKey('wallet.service.international'),
      );
      expect(
        international.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'it does nothing, so it offers no action',
      );
      handle.dispose();
    });

    testWidgets('the logo is read as RAAD', (tester) async {
      final handle = tester.ensureSemantics();
      await openApp(tester, signedIn: false);
      expect(find.bySemanticsLabel(en.logoLabel), findsOneWidget);
      handle.dispose();
    });
  });
}

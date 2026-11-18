// Log privacy (NFR10.10; review-01 R-01): NEVER write passwords, tokens or
// personal details into logs.
//
// The journeys below run the whole app against the contract fakes while
// everything written through print (a zone print override), debugPrint
// (replaced for the journey) and dart:io's stdout and stderr (IOOverrides) is
// captured. A journey fails if any captured text holds one of its synthetic
// passwords, confirmation or reset codes, tokens, account ids, email
// addresses, display names, amounts, request keys or history cursors. A
// failure names the kind of value and where it was written, never the value.
//
// dart:developer's log() writes to the VM service, which a test cannot read
// from inside its own isolate. tool/check_no_logging.dart therefore guards it,
// with every other console write, in the app's own code; its tests are at the
// end of this file, and CI also runs the tool as a step of its own.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/money/halalas.dart';

import '../tool/check_no_logging.dart';
import 'support/harness.dart';

/// One piece of text written while a journey ran, and where it was written.
typedef CapturedLine = ({String channel, String text});

/// Collects what is written through print, debugPrint, stdout and stderr
/// while a journey runs.
final class ConsoleCapture {
  final List<CapturedLine> lines = [];

  void _add(String channel, String text) =>
      lines.add((channel: channel, text: text));

  /// Runs [journey] with every console channel captured. Timers, microtasks
  /// and listeners the journey starts run in the same zone, so they are
  /// captured too. debugPrint is put back afterwards, even on failure.
  Future<void> run(Future<void> Function() journey) async {
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) =>
        _add('debugPrint', message ?? '');
    try {
      await IOOverrides.runZoned(
        () => runZoned(
          journey,
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => _add('print', line),
          ),
        ),
        stdout: () => _CapturedStdout(this, 'stdout'),
        stderr: () => _CapturedStdout(this, 'stderr'),
      );
    } finally {
      debugPrint = originalDebugPrint;
    }
  }
}

/// Stands in for dart:io's stdout or stderr and keeps what is written.
final class _CapturedStdout implements Stdout {
  _CapturedStdout(this._capture, this._channel);

  final ConsoleCapture _capture;
  final String _channel;

  @override
  Encoding encoding = utf8;

  @override
  void write(Object? object) => _capture._add(_channel, '$object');

  @override
  void writeln([Object? object = '']) => _capture._add(_channel, '$object');

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _capture._add(_channel, objects.join(separator));

  @override
  void writeCharCode(int charCode) =>
      _capture._add(_channel, String.fromCharCode(charCode));

  @override
  void add(List<int> data) =>
      _capture._add(_channel, utf8.decode(data, allowMalformed: true));

  // Nothing else on Stdout (terminal size, flush, close) writes text.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The private values one journey used, by kind.
final class PrivateValues {
  final Map<String, Set<String>> _byKind = {};

  void add(String kind, Iterable<String?> values) {
    for (final value in values) {
      final text = value?.trim().toLowerCase();
      if (text != null && text.isNotEmpty) (_byKind[kind] ??= {}).add(text);
    }
  }

  /// Each amount as integer halalas and as SAR with and without grouping,
  /// for example `100000`, `1,000.00` and `1000.00`.
  void addAmounts(Iterable<int> halalas) => add('amount', [
    for (final value in halalas) ...[
      '$value',
      formatHalalas(value, withCurrency: false),
      formatHalalas(value, withCurrency: false).replaceAll(',', ''),
    ],
  ]);

  int count(String kind) => _byKind[kind]?.length ?? 0;

  /// Where each kind of private value appears in [lines]: the kind, the
  /// channel and the line number, never the value itself.
  List<String> foundIn(List<CapturedLine> lines) => [
    for (final (index, line) in lines.indexed)
      for (final MapEntry(key: kind, value: values) in _byKind.entries)
        if (values.any(line.text.toLowerCase().contains))
          '$kind in ${line.channel} output, line ${index + 1}',
  ];
}

const transfers = 'POST /transfers';
const listTransfers = 'GET /transfers';

void main() {
  test('the capture sees print, debugPrint, stdout, stderr and later '
      'callbacks, and a leak is named without its value', () async {
    final before = debugPrint;
    final capture = ConsoleCapture();
    final values = PrivateValues()
      ..add('password', [fakeSara.password])
      ..add('token', [fakeSara.token])
      ..add('email address', [fakeSara.email])
      ..addAmounts([3719]);

    await capture.run(() async {
      // A deliberate leak, to prove the capture works.
      // ignore: avoid_print
      print('signing in with ${fakeSara.password}');
      debugPrint('Authorization: Bearer ${fakeSara.token}');
      stdout.writeln('sending 37.19 SAR');
      stderr.write('to ${fakeSara.email.toUpperCase()}');
      await Future<void>.delayed(
        Duration.zero,
        () => debugPrint('later: ${fakeSara.password}'),
      );
      final scheduled = Completer<void>();
      scheduleMicrotask(() {
        stdout.add(utf8.encode('microtask: 3719 halalas'));
        scheduled.complete();
      });
      await scheduled.future;
    });

    expect(debugPrint, same(before), reason: 'debugPrint is put back');
    expect(capture.lines.map((line) => line.channel), [
      'print',
      'debugPrint',
      'stdout',
      'stderr',
      'debugPrint',
      'stdout',
    ]);
    final found = values.foundIn(capture.lines);
    expect(found, [
      'password in print output, line 1',
      'token in debugPrint output, line 2',
      'amount in stdout output, line 3',
      'email address in stderr output, line 4',
      'password in debugPrint output, line 5',
      'amount in stdout output, line 6',
    ]);
    expect(found.join('\n'), isNot(contains(fakeSara.password)));
    expect(found.join('\n'), isNot(contains(fakeSara.token)));
  });

  testWidgets('in a widget test, writes from a build, a tap and a timer are '
      'captured too', (tester) async {
    final capture = ConsoleCapture();
    final values = PrivateValues()..add('token', [fakeSara.token]);

    await capture.run(() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              debugPrint('build ${fakeSara.token}');
              return GestureDetector(
                key: const ValueKey('canary'),
                behavior: HitTestBehavior.opaque,
                // A deliberate leak, to prove the capture works.
                // ignore: avoid_print
                onTap: () => print('tap ${fakeSara.token}'),
                child: const SizedBox(width: 100, height: 100),
              );
            },
          ),
        ),
      );
      await tester.tap(byKey('canary'));
      Timer(
        const Duration(seconds: 5),
        () => stderr.writeln('timer ${fakeSara.token}'),
      );
      await tester.pump(const Duration(seconds: 5));
    });

    expect(values.foundIn(capture.lines), [
      'token in debugPrint output, line 1',
      'token in print output, line 2',
      'token in stderr output, line 3',
    ]);
  });

  test('debugPrint is put back when a journey fails', () async {
    final before = debugPrint;
    await expectLater(
      ConsoleCapture().run(() async => throw StateError('journey failed')),
      throwsStateError,
    );
    expect(debugPrint, same(before));
  });

  testWidgets('account journey: sign-up, a resent and a wrong code, '
      'confirmation, a refused and a good sign-in, wallet set-up, sign-out '
      'and a password reset write none of their private values', (
    tester,
  ) async {
    final capture = ConsoleCapture();
    late Harness harness;
    const typedEmail = ' Amal.Hassan@Example.TEST ';
    const email = 'amal.hassan@example.test';
    const name = 'Amal Hassan';
    const password = 'Abcdef12';
    const wrongPassword = 'Wrongpass9';
    const newPassword = 'Newpass34';
    const wrongCode = '246810';
    late String firstCode;
    late String resentCode;
    late String resetCode;

    await capture.run(() async {
      harness = Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await tapKey(tester, 'signIn.signUp');
      await enter(tester, 'signUp.name', name);
      await enter(tester, 'signUp.email', typedEmail);
      await enter(tester, 'signUp.password', password);
      await tapKey(tester, 'signUp.submit');
      firstCode = harness.auth.confirmationCodeFor(email)!;
      await tapKey(tester, 'confirm.resend');
      resentCode = harness.auth.confirmationCodeFor(email)!;
      await enter(tester, 'confirm.code', wrongCode);
      await tapKey(tester, 'confirm.submit');
      expect(find.text(en.codeInvalid), findsOneWidget);
      await enter(tester, 'confirm.code', resentCode);
      await tapKey(tester, 'confirm.submit');
      expect(textOf(tester, 'signIn.notice'), en.signInNoticeEmailConfirmed);

      await enter(tester, 'signIn.password', wrongPassword);
      await tapKey(tester, 'signIn.submit');
      expect(textOf(tester, 'signIn.error'), en.signInRefused);
      await enter(tester, 'signIn.password', password);
      await tapKey(tester, 'signIn.submit');
      expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
      await tapKey(tester, 'wallet.signOut');

      await tapKey(tester, 'signIn.forgot');
      await enter(tester, 'forgot.email', typedEmail);
      await tapKey(tester, 'forgot.submit');
      resetCode = harness.auth.resetCodeFor(email)!;
      await enter(tester, 'reset.code', resetCode);
      await enter(tester, 'reset.password', newPassword);
      await tapKey(tester, 'reset.submit');
      await enter(tester, 'signIn.password', newPassword);
      await tapKey(tester, 'signIn.submit');
      expect(byKey('wallet.balance'), findsOneWidget);
      await tapKey(tester, 'wallet.signOut');
      expect(byKey('signIn.submit'), findsOneWidget);
    });

    // The journey went through every account action it claims to.
    expect(harness.auth.calls.toSet(), containsAll(FakeAuthOperation.values));
    expect(harness.backend.countOf('PUT /wallet'), 2);
    final amal = harness.directory.confirmedByEmail(email)!;
    final values = PrivateValues()
      ..add('password', [password, wrongPassword, newPassword])
      ..add('confirmation or reset code', [
        firstCode,
        resentCode,
        wrongCode,
        resetCode,
      ])
      ..add('token', [amal.token])
      ..add('account id', [amal.sub])
      ..add('email address', [typedEmail, email])
      ..add('display name', [name])
      ..addAmounts([FakeMoneyBackend.openingBalanceHalalas]);
    expect(values.count('confirmation or reset code'), 4);
    expect(values.foundIn(capture.lines), isEmpty);
  });

  testWidgets('money journey: sign-in, wallet and refresh, a send whose '
      'answer is lost then Try again, history with Load more and refresh, '
      'and sign-out write none of their private values', (tester) async {
    final capture = ConsoleCapture();
    late Harness harness;
    const typedRecipient = ' Omar@RAAD.test ';
    const sentHalalas = 3719;
    final received = [for (var i = 0; i < 25; i++) 4321 + 7 * i];

    await capture.run(() async {
      harness = Harness();
      harness.backend.openWallet(fakeOmar);
      for (final (i, halalas) in received.indexed) {
        harness.backend.seedTransfer(
          sender: fakeOmar,
          recipient: fakeSara,
          amountHalalas: halalas,
          completedAt: DateTime.utc(2026, 11, 1).add(Duration(hours: i)),
        );
      }
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await enter(tester, 'signIn.email', fakeSara.email);
      await enter(tester, 'signIn.password', fakeSara.password);
      await tapKey(tester, 'signIn.submit');
      expect(textOf(tester, 'wallet.balance'), '1,000.00 SAR');
      await tapKey(tester, 'wallet.refresh');

      await fillSendForm(tester, email: typedRecipient, amount: '37.19');
      await tapKey(tester, 'send.continue');
      harness.backend.failNext(transfers, FakeFault.lostResponseAfterCommit);
      await tapKey(tester, 'review.confirm');
      expect(byKey('review.outcomeUnknown'), findsOneWidget);
      await tapKey(tester, 'review.tryAgain');
      expect(textOf(tester, 'result.balance'), '962.81 SAR');
      await tapKey(tester, 'result.done');

      await tapKey(tester, 'wallet.seeAll');
      await tapKey(tester, 'history.loadMore');
      await showKey(tester, 'history.end');
      await tapKey(tester, 'history.refresh');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tapKey(tester, 'wallet.signOut');
      expect(byKey('signIn.submit'), findsOneWidget);
    });

    // The journey sent one transfer twice under one key and paged history.
    final keys = {
      for (final request in harness.backend.requests)
        if (request.operation == transfers) request.idempotencyKey,
    };
    final cursors = {
      for (final request in harness.backend.requests)
        if (request.operation == listTransfers) request.query['cursor'],
    }..remove(null);
    expect(harness.backend.countOf(transfers), 2);
    expect(keys, hasLength(1), reason: 'Try again sends the same key');
    expect(cursors, isNotEmpty, reason: 'Load more follows a cursor');
    expect(harness.backend.transfersBetween(fakeSara, fakeOmar), 1);
    expect(await harness.auth.hasSession(), isFalse);

    final opening = FakeMoneyBackend.openingBalanceHalalas;
    final values = PrivateValues()
      ..add('password', [fakeSara.password])
      ..add('token', [fakeSara.token])
      ..add('account id', [fakeSara.sub, fakeOmar.sub])
      ..add('email address', [fakeSara.email, fakeOmar.email, typedRecipient])
      ..add('display name', [fakeSara.displayName, fakeOmar.displayName])
      ..add('request key', keys)
      ..add('history cursor', cursors)
      ..addAmounts([sentHalalas, opening, opening - sentHalalas, ...received]);
    expect(values.count('request key'), 1);
    expect(values.foundIn(capture.lines), isEmpty);
  });

  group('tool/check_no_logging.dart', () {
    test('the app code in lib/ has no console or log write; generated code '
        'is not checked', () {
      final files = dartFilesToScan('lib');
      expect(
        files,
        containsAll(['lib/main.dart', 'lib/api/money_service.dart']),
      );
      expect(files.where((f) => f.startsWith('lib/api/generated/')), isEmpty);
      expect(files.where((f) => f.startsWith('lib/l10n/')), isEmpty);
      final calls = [
        for (final path in files)
          ...loggingCalls(path, File(path).readAsStringSync()),
      ];
      expect(calls, isEmpty);
    });

    test('it finds print, debugPrint, stdout, stderr, a prefixed developer '
        'log and a print tear-off, with their lines', () {
      const source = '''
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';

void leak(String token) {
  print(token);
  debugPrint(token);
  stdout.writeln(token);
  stderr.write(token);
  dev.log(token);
  [token].forEach(print);
}
''';
      expect(loggingCalls('lib/leak.dart', source).map((c) => '$c'), [
        'lib/leak.dart:6: uses print',
        'lib/leak.dart:7: uses debugPrint',
        'lib/leak.dart:8: uses stdout',
        'lib/leak.dart:9: uses stderr',
        'lib/leak.dart:10: uses log from dart:developer',
        'lib/leak.dart:11: uses print',
      ]);
    });

    test('it finds the debugPrint family and the tree dumps', () {
      const source = '''
void f() {
  debugPrintStack(label: 'x');
  debugPrintSynchronously('x');
  debugPrintBeginFrameBanner = true;
  debugDumpApp();
}
''';
      expect(loggingCalls('lib/f.dart', source).map((c) => c.name), [
        'debugPrintStack',
        'debugPrintSynchronously',
        'debugPrintBeginFrameBanner',
        'debugDumpApp',
      ]);
    });

    test('log is found only when it comes from dart:developer', () {
      expect(
        loggingCalls(
          'lib/a.dart',
          "import 'dart:developer';\nvoid f() => log('x');\n",
        ),
        hasLength(1),
      );
      expect(
        loggingCalls('lib/b.dart', "import 'dart:math';\nfinal x = log(2);\n"),
        isEmpty,
      );
      expect(
        loggingCalls(
          'lib/c.dart',
          "import 'dart:math' as math;\n"
              "import 'dart:developer' as dev;\n"
              'final x = math.log(2);\n',
        ),
        isEmpty,
      );
    });

    test('comments, string text and longer names are not writes', () {
      const source = r"""
/// Never print( a token; debugPrint('x') and stdout stay quiet.
// stderr.write(token);
/* print('a') /* nested stdout */ debugPrint('b') */
const a = 'print(token)';
const b = r"stderr $x";
const c = '''
debugPrint(token);
''';
const d = 'cost: $amount';
final fingerprint = 'reprint';
void reprint() {}
// import 'dart:developer';
final e = log(2);
""";
      expect(codeOnly(source), hasLength(source.length));
      expect(
        '\n'.allMatches(codeOnly(source)).length,
        '\n'.allMatches(source).length,
      );
      expect(loggingCalls('lib/quiet.dart', source), isEmpty);
    });

    test('code inside a string interpolation is still checked', () {
      expect(
        loggingCalls(
          'lib/i.dart',
          r"final s = 'columns: ${stdout.terminalColumns} ${'print'}';",
        ).map((c) => c.name),
        ['stdout'],
      );
    });

    test('generated folders are left out', () {
      expect(isScanned('lib/api/generated/money_api_client.dart'), isFalse);
      expect(isScanned('lib/l10n/app_localizations.dart'), isFalse);
      expect(isScanned('lib/screens/wallet_screen.dart'), isTrue);
    });
  });
}

// Consumer checks for C1 (contract-summary "Contract Test Responsibilities"):
// the pinned copy is U2's file and intact, the contract fake answers in the
// pinned shapes with U2's rules, the app sends only the pinned request
// shapes, and the generated client survives unknown response fields and
// codes.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:raad_mobile/api/generated/money_api_client.dart';
import 'package:raad_mobile/api/money_service.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/l10n/app_localizations.dart';
import 'package:raad_mobile/ui/messages.dart';
import 'package:yaml/yaml.dart';

import 'support/fakes.dart';

const pinnedPath = 'contracts/pinned/c1-money-api/raad-money-v1.yaml';
const u2Commit = '2b3660b9d05c0a06f5018f61b74f6621289924ec';
const u2Sha256 =
    '31780d203ceb04f4a9e16e99e53573addab97dc7b1713e6918d5615237a9ece0';

Object? plain(Object? yaml) => jsonDecode(jsonEncode(yaml));

final AppLocalizations english = lookupAppLocalizations(const Locale('en'));

/// Answers every request with one fixed response and keeps what it was
/// asked.
final class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.status, this.body, {this.headers = const {}});

  final int status;
  final Map<String, Object?> body;
  final Map<String, List<String>> headers;
  final List<RequestOptions> seen = [];

  int get calls => seen.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Times out every request, moving [clock] on by [takes] each time.
final class TimeoutAdapter implements HttpClientAdapter {
  TimeoutAdapter(this.clock, this.takes);

  final FakeClock clock;
  final Duration takes;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    clock.advance(takes);
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _NetworkDownAuth implements TokenSource {
  @override
  Future<String?> accessToken() async =>
      throw const AuthFailure(AuthFailureCode.network);
}

Map<String, Object?> errorBody(String code) => {
  'code': code,
  'message': 'Server text the app never shows.',
  'correlationId': 'c-1',
};

MoneyService serviceWith(
  HttpClientAdapter adapter, {
  TokenSource? auth,
  List<Duration>? waits,
  FakeClock? clock,
}) => MoneyService.create(
  baseUrl: FakeMoneyBackend.baseUrl,
  auth: auth ?? (FakeAuthService()..signInAs(fakeSara)),
  adapter: adapter,
  retryDelay: (wait) async => waits?.add(wait),
  now: clock?.call,
  random: Random(7),
);

void main() {
  late Map<String, Object?> openApi;

  setUpAll(() {
    openApi =
        plain(loadYaml(File(pinnedPath).readAsStringSync()))!
            as Map<String, Object?>;
  });

  Map<String, Object?> components() =>
      openApi['components']! as Map<String, Object?>;

  JsonSchema schemaOf(Map<String, Object?> schema) => JsonSchema.create({
    ...schema,
    // Only the schema section, so `$ref`s resolve against the pinned file's
    // own definitions.
    'components': {'schemas': components()['schemas']},
  }, schemaVersion: SchemaVersion.draft2020_12);

  JsonSchema component(String name) =>
      schemaOf({r'$ref': '#/components/schemas/$name'});

  group('Pinned contract', () {
    test('the pinned copy matches the SHA-256 in pins.yaml', () {
      final pins =
          loadYaml(File('contracts/pins.yaml').readAsStringSync()) as YamlMap;
      final entries = (pins['pins'] as YamlList).cast<YamlMap>();
      expect(entries, isNotEmpty);
      for (final pin in entries) {
        final bytes = File(pin['copy'] as String).readAsBytesSync();
        expect(
          sha256.convert(bytes).toString(),
          pin['sha256'],
          reason: '${pin['contract']} copy differs from its pin',
        );
        expect(pin['commit'], matches(RegExp(r'^[0-9a-f]{40}$')));
      }
    });

    test("C1 is pinned to U2's 1.0.0-u2.1 file at 2b3660b", () {
      final pins =
          loadYaml(File('contracts/pins.yaml').readAsStringSync()) as YamlMap;
      final c1 = (pins['pins'] as YamlList).cast<YamlMap>().singleWhere(
        (pin) => pin['contract'] == 'c1-money-api',
      );
      expect(c1['owner'], '00az/RaadMoneyService');
      expect(c1['file'], 'openapi/raad-money-v1.yaml');
      expect(c1['commit'], u2Commit);
      expect(c1['sha256'], u2Sha256);
      expect((openApi['info']! as Map)['version'], '1.0.0-u2.1');
    });

    test('the pin declares the full v1 behaviour the app now relies on', () {
      // U1's partial-release marker is gone: replay, the amount range and
      // cursor paging are in force.
      expect(openApi.containsKey('x-u1-conformance'), isFalse);
      final schemas = components()['schemas']! as Map;
      final codes =
          (((schemas['Error'] as Map)['properties'] as Map)['code']
                  as Map)['enum']
              as List;
      expect(
        codes,
        containsAll([
          'CURSOR_INVALID_OR_EXPIRED',
          'IDEMPOTENCY_KEY_REUSED',
          'AMOUNT_OUT_OF_RANGE',
          'RATE_LIMITED',
        ]),
      );
      final amount =
          ((schemas['CreateTransferRequest'] as Map)['properties']
                  as Map)['amountHalalas']
              as Map;
      expect(
        amount.containsKey('minimum'),
        isFalse,
        reason: 'the range is a saved 422 business refusal, never a 400',
      );
      final rateLimited =
          (components()['responses']! as Map)['RateLimited'] as Map;
      expect((rateLimited['headers'] as Map).keys, contains('Retry-After'));
    });

    test('the generated client was made from that contract version', () {
      final info = openApi['info']! as Map<String, Object?>;
      expect(MoneyApiClient.apiVersion, info['version']);
      expect(MoneyApiClient.specVersion, openApi['openapi']);
    });
  });

  group('Contract fake answers in the pinned shapes', () {
    late FakeClock clock;
    late FakeMoneyBackend backend;
    late Dio dio;

    JsonSchema schemaFor(String path, String method, int status) {
      final operation =
          ((openApi['paths']! as Map)[path] as Map)[method] as Map;
      var response = (operation['responses'] as Map)['$status'] as Map;
      final ref = response[r'$ref'];
      if (ref is String) {
        response =
            (components()['responses']! as Map)[ref.split('/').last] as Map;
      }
      final schema =
          ((response['content'] as Map)['application/json'] as Map)['schema'];
      return schemaOf(schema as Map<String, Object?>);
    }

    Future<Response<Object?>> call(
      String method,
      String path, {
      Object? body,
      FakeAccount? as = fakeSara,
      String? key,
    }) {
      return dio.request<Object?>(
        path,
        data: body == null ? null : jsonEncode(body),
        options: Options(
          method: method,
          contentType: 'application/json',
          validateStatus: (_) => true,
          headers: {
            if (as != null) 'Authorization': 'Bearer ${as.token}',
            'Idempotency-Key': ?key,
          },
        ),
      );
    }

    void expectConforms(
      Response<Object?> response,
      String path,
      String method,
    ) {
      final schema = schemaFor(path, method, response.statusCode!);
      final result = schema.validate(response.data);
      expect(
        result.isValid,
        isTrue,
        reason: '$method $path ${response.statusCode}: ${result.errors}',
      );
    }

    String? replayed(Response<Object?> response) =>
        response.headers.value('idempotency-replayed');

    Map<String, Object?> sendTo(String email, Object amount) => {
      'recipientEmail': email,
      'amountHalalas': amount,
    };

    setUp(() {
      clock = FakeClock();
      backend = FakeMoneyBackend(now: clock.call)..openWallet(fakeOmar);
      dio = Dio(BaseOptions(baseUrl: FakeMoneyBackend.baseUrl))
        ..httpClientAdapter = backend;
    });

    test('the schema check refuses shapes the contract does not allow', () {
      final error = schemaFor('/wallet', 'get', 404);
      expect(
        error.validate({
          'error': {'code': 'WALLET_NOT_FOUND', 'message': 'm'},
        }).isValid,
        isFalse,
        reason: 'C1 errors are flat; there is no nested error object',
      );
      final wallet = schemaFor('/wallet', 'get', 200);
      expect(
        wallet.validate({
          'balance': {'amountHalalas': 10.5, 'currency': 'SAR'},
        }).isValid,
        isFalse,
        reason: 'amounts are whole halalas',
      );
      expect(
        wallet.validate({
          'balance': {'amountHalalas': 100, 'currency': 'USD'},
        }).isValid,
        isFalse,
      );
    });

    test('wallet setup can repeat without a second opening credit', () async {
      final missing = await call('GET', '/wallet');
      expect(missing.statusCode, 404);
      expect((missing.data! as Map)['code'], 'WALLET_NOT_FOUND');
      expectConforms(missing, '/wallet', 'get');

      final created = await call('PUT', '/wallet');
      expect(created.statusCode, 201);
      expectConforms(created, '/wallet', 'put');

      final again = await call('PUT', '/wallet');
      expect(again.statusCode, 200);
      expectConforms(again, '/wallet', 'put');
      expect(backend.balanceOf(fakeSara), 100000);

      final read = await call('GET', '/wallet');
      expect(read.statusCode, 200);
      expectConforms(read, '/wallet', 'get');

      final anonymous = await call('GET', '/wallet', as: null);
      expect(anonymous.statusCode, 401);
      expectConforms(anonymous, '/wallet', 'get');
    });

    test('recipient lookup outcomes', () async {
      await call('PUT', '/wallet');
      final cases = {
        ' OMAR@raad.test ': 200,
        'nobody@raad.test': 404,
        fakeSara.email: 409,
        'not-an-email': 400,
      };
      for (final MapEntry(key: email, value: status) in cases.entries) {
        final response = await call(
          'POST',
          '/recipients/resolve',
          body: {'email': email},
        );
        expect(response.statusCode, status, reason: email);
        expectConforms(response, '/recipients/resolve', 'post');
      }
    });

    test('transfer outcomes under U2: the 100 to 50000 range and the '
        'refusal order', () async {
      await call('PUT', '/wallet');
      final cases = <(Map<String, Object?>, int, String?, String?)>[
        (sendTo('omar@raad.test', 10000), 201, null, 'false'),
        (
          sendTo('nobody@raad.test', 10000),
          404,
          'RECIPIENT_NOT_FOUND',
          'false',
        ),
        (sendTo('omar@raad.test', 99), 422, 'AMOUNT_OUT_OF_RANGE', 'false'),
        (sendTo('omar@raad.test', 100), 201, null, 'false'),
        (sendTo('omar@raad.test', 50000), 201, null, 'false'),
        (sendTo('omar@raad.test', 50001), 422, 'AMOUNT_OUT_OF_RANGE', 'false'),
        (sendTo('omar@raad.test', 0), 422, 'AMOUNT_OUT_OF_RANGE', 'false'),
        (sendTo('omar@raad.test', -5), 422, 'AMOUNT_OUT_OF_RANGE', 'false'),
        (sendTo(fakeSara.email, 10000), 409, 'SELF_TRANSFER', 'false'),
        // Balance is now 39,900 halalas.
        (sendTo('omar@raad.test', 40000), 422, 'INSUFFICIENT_FUNDS', 'false'),
        // Refusal order: unknown recipient, range, own wallet, balance.
        (sendTo('nobody@raad.test', 99), 404, 'RECIPIENT_NOT_FOUND', 'false'),
        (sendTo(fakeSara.email, 99), 422, 'AMOUNT_OUT_OF_RANGE', 'false'),
        (sendTo(fakeSara.email, 40000), 409, 'SELF_TRANSFER', 'false'),
        // Schema refusals save nothing and carry no replay header.
        (sendTo('omar@raad.test', 1.5), 400, 'VALIDATION_ERROR', null),
        (
          {...sendTo('omar@raad.test', 100), 'note': 'x'},
          400,
          'VALIDATION_ERROR',
          null,
        ),
      ];
      var n = 0;
      for (final (body, status, code, header) in cases) {
        n++;
        final response = await call(
          'POST',
          '/transfers',
          body: body,
          key: 'contract-test-key-$n',
        );
        expect(response.statusCode, status, reason: '$body');
        if (code != null) {
          expect((response.data! as Map)['code'], code, reason: '$body');
        }
        expect(replayed(response), header, reason: '$body');
        expectConforms(response, '/transfers', 'post');
      }
      expect(backend.balanceOf(fakeSara), 39900);
      expect(backend.balanceOf(fakeOmar), 160100);

      final badKey = await call(
        'POST',
        '/transfers',
        body: sendTo('omar@raad.test', 100),
        key: 'short',
      );
      expect(badKey.statusCode, 400);
      expect(replayed(badKey), isNull);
    });

    test(
      'a repeated key replays the first outcome and moves money once',
      () async {
        await call('PUT', '/wallet');
        const key = 'replay-key-000001';
        final first = await call(
          'POST',
          '/transfers',
          body: sendTo(' OMAR@raad.test ', 10000),
          key: key,
        );
        final again = await call(
          'POST',
          '/transfers',
          body: sendTo('omar@raad.test', 10000),
          key: key,
        );
        expect(first.statusCode, 201);
        expect(again.statusCode, 201);
        expect(replayed(first), 'false');
        expect(replayed(again), 'true');
        expect(again.data, first.data);
        expectConforms(again, '/transfers', 'post');
        expect(backend.balanceOf(fakeSara), 90000);
        expect(backend.transfersBetween(fakeSara, fakeOmar), 1);

        final reused = await call(
          'POST',
          '/transfers',
          body: sendTo('omar@raad.test', 10001),
          key: key,
        );
        expect(reused.statusCode, 409);
        expect((reused.data! as Map)['code'], 'IDEMPOTENCY_KEY_REUSED');
        expect(replayed(reused), 'false');
        expectConforms(reused, '/transfers', 'post');
        expect(backend.balanceOf(fakeSara), 90000);

        // A refused first outcome is replayed too, even after money arrives.
        backend.setBalance(fakeSara, 50);
        const refusedKey = 'replay-key-000002';
        final low = await call(
          'POST',
          '/transfers',
          body: sendTo('omar@raad.test', 200),
          key: refusedKey,
        );
        backend.setBalance(fakeSara, 90000);
        final lowAgain = await call(
          'POST',
          '/transfers',
          body: sendTo('omar@raad.test', 200),
          key: refusedKey,
        );
        expect((low.data! as Map)['code'], 'INSUFFICIENT_FUNDS');
        expect(lowAgain.statusCode, 422);
        expect((lowAgain.data! as Map)['code'], 'INSUFFICIENT_FUNDS');
        expect(replayed(lowAgain), 'true');
        expect(
          (lowAgain.data! as Map)['correlationId'],
          isNot((low.data! as Map)['correlationId']),
        );
        expect(backend.balanceOf(fakeSara), 90000);
      },
    );

    test(
      'a missing wallet or a rate limit saves nothing against the key',
      () async {
        const key = 'nothing-saved-0001'; // gitleaks:allow (test request key)
        final noWallet = await call(
          'POST',
          '/transfers',
          body: sendTo('omar@raad.test', 100),
          key: key,
        );
        expect(noWallet.statusCode, 404);
        expect((noWallet.data! as Map)['code'], 'WALLET_NOT_FOUND');
        expect(replayed(noWallet), isNull);
        expectConforms(noWallet, '/transfers', 'post');

        await call('PUT', '/wallet');
        backend.answerNext(
          'POST /transfers',
          429,
          'RATE_LIMITED',
          retryAfterSeconds: 30,
        );
        final limited = await call(
          'POST',
          '/transfers',
          body: sendTo('omar@raad.test', 100),
          key: key,
        );
        expect(limited.statusCode, 429);
        expect(limited.headers.value('retry-after'), '30');
        expect(replayed(limited), isNull);
        expectConforms(limited, '/transfers', 'post');

        final sent = await call(
          'POST',
          '/transfers',
          body: sendTo('omar@raad.test', 100),
          key: key,
        );
        expect(sent.statusCode, 201);
        expect(replayed(sent), 'false');
      },
    );

    test('history pages follow the opaque cursor with no gap or repeat', () async {
      await call('PUT', '/wallet');
      for (var i = 0; i < 45; i++) {
        backend.seedTransfer(
          sender: i.isEven ? fakeSara : fakeOmar,
          recipient: i.isEven ? fakeOmar : fakeSara,
          amountHalalas: 100 + i,
          completedAt: DateTime.utc(2026, 11, 1).add(Duration(minutes: i)),
        );
      }
      final seen = <String>[];
      String? cursor;
      var pages = 0;
      do {
        final page = await call(
          'GET',
          cursor == null
              ? '/transfers?limit=20'
              : '/transfers?limit=20&cursor=${Uri.encodeQueryComponent(cursor)}',
        );
        expect(page.statusCode, 200);
        expectConforms(page, '/transfers', 'get');
        final data = page.data! as Map;
        seen.addAll([
          for (final item in data['items'] as List)
            (item as Map)['transferId'] as String,
        ]);
        cursor = data['nextCursor'] as String?;
        expect(data['hasMore'], cursor != null);
        pages++;
        if (pages == 1) {
          // A transfer made after page one never shifts the later pages.
          await call(
            'POST',
            '/transfers',
            body: sendTo('omar@raad.test', 100),
            key: 'during-paging-0001',
          );
        }
      } while (cursor != null);
      expect(pages, 3);
      expect(seen, hasLength(45));
      expect(seen.toSet(), hasLength(45));
    });

    test(
      'an altered, expired, foreign or resized cursor asks for page one',
      () async {
        await call('PUT', '/wallet');
        for (var i = 0; i < 3; i++) {
          backend.seedTransfer(
            sender: fakeSara,
            recipient: fakeOmar,
            amountHalalas: 100,
            completedAt: DateTime.utc(2026, 11, 1, i),
          );
        }
        final first = await call('GET', '/transfers?limit=1');
        final cursor = (first.data! as Map)['nextCursor'] as String;
        final altered =
            '${cursor.substring(0, cursor.length - 1)}'
            '${cursor.endsWith('0') ? '1' : '0'}';

        Future<void> expectRestart(String query, {FakeAccount? as}) async {
          final response = await call(
            'GET',
            '/transfers?$query',
            as: as ?? fakeSara,
          );
          expect(response.statusCode, 400, reason: query);
          expect(
            (response.data! as Map)['code'],
            'CURSOR_INVALID_OR_EXPIRED',
            reason: query,
          );
          expectConforms(response, '/transfers', 'get');
        }

        String q(String c, int limit) =>
            'limit=$limit&cursor=${Uri.encodeQueryComponent(c)}';

        await expectRestart(q(altered, 1));
        await expectRestart(q(cursor, 2));
        backend.openWallet(fakeSara);
        await expectRestart(q(cursor, 1), as: fakeOmar);
        clock.advance(FakeMoneyBackend.cursorLifetime);
        await expectRestart(q(cursor, 1));
      },
    );
  });

  group('Generated client compatibility', () {
    test(
      'ignores an unknown response field and keeps the known ones',
      () async {
        final money = serviceWith(
          StubAdapter(200, {
            'balance': {'amountHalalas': 4200, 'currency': 'SAR', 'scale': 2},
            'tier': 'gold',
          }),
        );
        final balance = await money.getBalance();
        expect(balance.amountHalalas, 4200);
        expect(balance.currency, MoneyCurrency.sar);
      },
    );

    test('keeps an unknown Error.code for the safe fallback message', () async {
      final money = serviceWith(StubAdapter(409, errorBody('WALLET_FROZEN')));
      await expectLater(
        money.resolveRecipient('omar@raad.test'),
        throwsA(
          isA<MoneyApiException>()
              .having((e) => e.code, 'code', 'WALLET_FROZEN')
              .having((e) => e.status, 'status', 409)
              .having((e) => e.correlationId, 'correlationId', 'c-1')
              .having(
                (e) => Messages.forMoneyError(english, e),
                'message',
                english.genericError,
              ),
        ),
      );
    });

    test('the app sends exactly the pinned request shapes', () async {
      final backend = FakeMoneyBackend()
        ..openWallet(fakeOmar)
        ..openWallet(fakeSara);
      final money = serviceWith(backend);
      await money.resolveRecipient('omar@raad.test');
      await money.createTransfer(
        recipientEmail: 'omar@raad.test',
        amountHalalas: 100,
        idempotencyKey: '0b6a5d2e-0000-4000-8000-000000000001',
      );
      final resolveSchema = component('ResolveRecipientRequest');
      final transferSchema = component('CreateTransferRequest');
      final resolve = backend.requests.singleWhere(
        (r) => r.operation == 'POST /recipients/resolve',
      );
      final transfer = backend.requests.singleWhere(
        (r) => r.operation == 'POST /transfers',
      );
      expect(resolveSchema.validate(resolve.body).isValid, isTrue);
      expect(transferSchema.validate(transfer.body).isValid, isTrue);
      expect(
        transfer.idempotencyKey,
        matches(RegExp(r'^[A-Za-z0-9._~-]{16,128}$')),
      );
      // The request schemas are closed, so the check above is strict.
      expect(
        transferSchema.validate({
          ...transfer.body! as Map<String, Object?>,
          'sourceWalletId': 'w-1',
        }).isValid,
        isFalse,
      );
    });

    test('a history page sends the exact cursor and page size', () async {
      final stub = StubAdapter(200, {'items': <Object>[], 'nextCursor': null});
      final money = serviceWith(stub);
      await money.historyPage();
      await money.historyPage(cursor: 'opaque+/=cursor', limit: 20);
      expect(stub.seen.first.uri.queryParameters, {'limit': '20'});
      expect(stub.seen.last.uri.queryParameters, {
        'cursor': 'opaque+/=cursor',
        'limit': '20',
      });
      expect(() => money.historyPage(limit: 101), throwsRangeError);
      expect(() => money.historyPage(limit: 0), throwsRangeError);
    });

    test(
      'a read is retried once after a 500 or 503, never after a 429',
      () async {
        for (final (status, code, calls) in [
          (429, 'RATE_LIMITED', 1),
          (503, 'SERVICE_UNAVAILABLE', 2),
          (500, 'INTERNAL_ERROR', 2),
        ]) {
          final stub = StubAdapter(status, errorBody(code));
          await expectLater(
            serviceWith(stub).getBalance(),
            throwsA(
              isA<MoneyApiException>().having((e) => e.code, 'code', code),
            ),
          );
          expect(stub.calls, calls, reason: '$status');
        }
      },
    );

    test(
      'the pause before a read retry is 250 to 750 ms, or Retry-After',
      () async {
        final waits = <Duration>[];
        await expectLater(
          serviceWith(
            StubAdapter(500, errorBody('INTERNAL_ERROR')),
            waits: waits,
          ).getBalance(),
          throwsA(isA<MoneyApiException>()),
        );
        expect(waits.single.inMilliseconds, inInclusiveRange(250, 750));

        waits.clear();
        await expectLater(
          serviceWith(
            StubAdapter(
              503,
              errorBody('SERVICE_UNAVAILABLE'),
              headers: {
                'retry-after': ['3'],
              },
            ),
            waits: waits,
          ).ensureWallet(),
          throwsA(isA<MoneyApiException>()),
        );
        expect(waits.single, const Duration(seconds: 3));
      },
    );

    test(
      'a retry that would not fit the 15-second deadline is not made',
      () async {
        final late = StubAdapter(
          503,
          errorBody('SERVICE_UNAVAILABLE'),
          headers: {
            'retry-after': ['20'],
          },
        );
        await expectLater(
          serviceWith(late).historyPage(),
          throwsA(
            isA<MoneyApiException>().having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 20),
            ),
          ),
        );
        expect(late.calls, 1);

        final clock = FakeClock();
        final slow = TimeoutAdapter(clock, const Duration(seconds: 15));
        await expectLater(
          serviceWith(slow, clock: clock).getBalance(),
          throwsA(
            isA<MoneyApiException>().having(
              (e) => e.code,
              'code',
              MoneyErrorCode.network,
            ),
          ),
        );
        expect(slow.calls, 1, reason: 'the deadline is already used up');

        final quick = TimeoutAdapter(clock, const Duration(seconds: 2));
        await expectLater(
          serviceWith(quick, clock: clock).getBalance(),
          throwsA(isA<MoneyApiException>()),
        );
        expect(quick.calls, 2, reason: 'one retry fits in the deadline');
      },
    );

    test('a 429 carries Retry-After and is never retried', () async {
      final stub = StubAdapter(
        429,
        errorBody('RATE_LIMITED'),
        headers: {
          'retry-after': ['30'],
        },
      );
      await expectLater(
        serviceWith(stub).resolveRecipient('omar@raad.test'),
        throwsA(
          isA<MoneyApiException>()
              .having((e) => e.isRateLimited, 'rate limited', isTrue)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 30),
              ),
        ),
      );
      expect(stub.calls, 1);
    });

    test('a transfer is never retried, even after 500', () async {
      final stub = StubAdapter(500, errorBody('INTERNAL_ERROR'));
      await expectLater(
        serviceWith(stub).createTransfer(
          recipientEmail: 'omar@raad.test',
          amountHalalas: 100,
          idempotencyKey: 'aaaaaaaaaaaaaaaa',
        ),
        throwsA(isA<TransferOutcomeUnknown>()),
      );
      expect(stub.calls, 1);
    });

    test('a refused transfer is a definite answer with its status', () async {
      final stub = StubAdapter(422, errorBody('AMOUNT_OUT_OF_RANGE'));
      await expectLater(
        serviceWith(stub).createTransfer(
          recipientEmail: 'omar@raad.test',
          amountHalalas: 99,
          idempotencyKey: 'aaaaaaaaaaaaaaaa',
        ),
        throwsA(
          isA<MoneyApiException>()
              .having((e) => e.code, 'code', 'AMOUNT_OUT_OF_RANGE')
              .having((e) => e.status, 'status', 422),
        ),
      );
    });

    test(
      'an unreadable success body leaves the transfer outcome unknown',
      () async {
        final stub = StubAdapter(201, {'transferId': 'only-this'});
        await expectLater(
          serviceWith(stub).createTransfer(
            recipientEmail: 'omar@raad.test',
            amountHalalas: 100,
            idempotencyKey: 'aaaaaaaaaaaaaaaa',
          ),
          throwsA(isA<TransferOutcomeUnknown>()),
        );
      },
    );

    test('without a session nothing is sent', () async {
      final stub = StubAdapter(200, {});
      await expectLater(
        serviceWith(stub, auth: FakeAuthService()).createTransfer(
          recipientEmail: 'omar@raad.test',
          amountHalalas: 100,
          idempotencyKey: 'aaaaaaaaaaaaaaaa',
        ),
        throwsA(
          isA<MoneyApiException>().having(
            (e) => e.isAuthenticationRequired,
            'auth required',
            isTrue,
          ),
        ),
      );
      expect(stub.calls, 0);
    });

    test(
      'a token refresh that cannot reach sign-in is a network error',
      () async {
        final stub = StubAdapter(200, {});
        await expectLater(
          serviceWith(stub, auth: _NetworkDownAuth()).getBalance(),
          throwsA(
            isA<MoneyApiException>().having(
              (e) => e.code,
              'code',
              MoneyErrorCode.network,
            ),
          ),
        );
        expect(stub.calls, 0);
      },
    );
  });
}

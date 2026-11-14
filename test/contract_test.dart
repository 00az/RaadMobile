// Consumer checks for C1 (contract-summary "Contract Test Responsibilities"):
// the pinned copy is intact, the contract fake answers in the pinned shapes,
// and the generated client survives unknown response fields and codes.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:raad_mobile/api/generated/money_api_client.dart';
import 'package:raad_mobile/api/money_service.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/dev/fake_accounts.dart';
import 'package:raad_mobile/dev/fake_auth_service.dart';
import 'package:raad_mobile/dev/fake_money_backend.dart';
import 'package:raad_mobile/ui/messages.dart';
import 'package:yaml/yaml.dart';

const pinnedPath = 'contracts/pinned/c1-money-api/raad-money-v1.yaml';

Object? plain(Object? yaml) => jsonDecode(jsonEncode(yaml));

/// Answers every request with one fixed response.
final class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.status, this.body);

  final int status;
  final Map<String, Object?> body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _NetworkDownAuth implements AuthService {
  @override
  Future<String?> accessToken() async =>
      throw const AuthFailure(AuthFailureCode.network);
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}
}

MoneyService serviceWith(HttpClientAdapter adapter, {AuthService? auth}) =>
    MoneyService.create(
      baseUrl: FakeMoneyBackend.baseUrl,
      auth: auth ?? (FakeAuthService()..signInAs(fakeSara)),
      adapter: adapter,
    );

void main() {
  late Map<String, Object?> openApi;

  setUpAll(() {
    openApi =
        plain(loadYaml(File(pinnedPath).readAsStringSync()))!
            as Map<String, Object?>;
  });

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

    test('the generated client was made from that contract version', () {
      final info = openApi['info']! as Map<String, Object?>;
      expect(MoneyApiClient.apiVersion, info['version']);
      expect(MoneyApiClient.specVersion, openApi['openapi']);
    });
  });

  group('Contract fake answers in the pinned shapes', () {
    late FakeMoneyBackend backend;
    late Dio dio;

    JsonSchema schemaFor(String path, String method, int status) {
      final operation =
          ((openApi['paths']! as Map)[path] as Map)[method] as Map;
      var response = (operation['responses'] as Map)['$status'] as Map;
      final ref = response[r'$ref'];
      if (ref is String) {
        response =
            ((openApi['components']! as Map)['responses'] as Map)[ref
                    .split('/')
                    .last]
                as Map;
      }
      final schema =
          ((response['content'] as Map)['application/json'] as Map)['schema'];
      final components = openApi['components']! as Map<String, Object?>;
      return JsonSchema.create({
        ...schema as Map<String, Object?>,
        // Only the schema section, so `$ref`s resolve against the pinned
        // file's own definitions.
        'components': {'schemas': components['schemas']},
      }, schemaVersion: SchemaVersion.draft2020_12);
    }

    Future<Response<Object?>> call(
      String method,
      String path, {
      Object? body,
      String token = 'sara',
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
            if (token == 'sara') 'Authorization': 'Bearer ${fakeSara.token}',
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

    setUp(() {
      backend = FakeMoneyBackend()..openWallet(fakeOmar);
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

    test('wallet setup and reads', () async {
      final missing = await call('GET', '/wallet');
      expect(missing.statusCode, 404);
      expect((missing.data! as Map)['code'], 'WALLET_NOT_FOUND');
      expectConforms(missing, '/wallet', 'get');

      final created = await call('PUT', '/wallet');
      expect(created.statusCode, 201);
      expectConforms(created, '/wallet', 'put');

      final existing = await call('PUT', '/wallet');
      expect(existing.statusCode, 200);
      expectConforms(existing, '/wallet', 'put');

      final read = await call('GET', '/wallet');
      expect(read.statusCode, 200);
      expectConforms(read, '/wallet', 'get');

      final anonymous = await call('GET', '/wallet', token: 'none');
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

    test(
      'transfer outcomes, with Idempotency-Replayed only where persisted',
      () async {
        await call('PUT', '/wallet');
        final cases = <(Map<String, Object?>, int, String?)>[
          (
            {'recipientEmail': 'omar@raad.test', 'amountHalalas': 10000},
            201,
            null,
          ),
          (
            {'recipientEmail': 'nobody@raad.test', 'amountHalalas': 10000},
            404,
            'RECIPIENT_NOT_FOUND',
          ),
          (
            {'recipientEmail': 'omar@raad.test', 'amountHalalas': 99},
            422,
            'AMOUNT_OUT_OF_RANGE',
          ),
          (
            {'recipientEmail': fakeSara.email, 'amountHalalas': 10000},
            409,
            'SELF_TRANSFER',
          ),
          (
            {'recipientEmail': 'omar@raad.test', 'amountHalalas': 50000},
            201,
            null,
          ),
          (
            {'recipientEmail': 'omar@raad.test', 'amountHalalas': 50000},
            422,
            'INSUFFICIENT_FUNDS',
          ),
          (
            {'recipientEmail': 'omar@raad.test', 'amountHalalas': 1.5},
            400,
            'VALIDATION_ERROR',
          ),
          (
            {
              'recipientEmail': 'omar@raad.test',
              'amountHalalas': 100,
              'note': 'x',
            },
            400,
            'VALIDATION_ERROR',
          ),
        ];
        var n = 0;
        for (final (body, status, code) in cases) {
          n++;
          final response = await call(
            'POST',
            '/transfers',
            body: body,
            key: 'contract-test-key-$n',
          );
          expect(response.statusCode, status, reason: '$body');
          if (code != null) expect((response.data! as Map)['code'], code);
          expectConforms(response, '/transfers', 'post');
          final replayed = response.headers.value('idempotency-replayed');
          expect(replayed, status == 400 ? isNull : 'false', reason: '$body');
        }

        final badKey = await call(
          'POST',
          '/transfers',
          body: {'recipientEmail': 'omar@raad.test', 'amountHalalas': 100},
          key: 'short',
        );
        expect(badKey.statusCode, 400);
        expect(badKey.headers.value('idempotency-replayed'), isNull);
      },
    );

    test('history page', () async {
      await call('PUT', '/wallet');
      await call(
        'POST',
        '/transfers',
        body: {'recipientEmail': 'omar@raad.test', 'amountHalalas': 10000},
        key: 'contract-test-history',
      );
      final page = await call('GET', '/transfers');
      expect(page.statusCode, 200);
      expect(((page.data! as Map)['items'] as List), hasLength(1));
      expectConforms(page, '/transfers', 'get');
    });
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

    test('keeps an unknown Error.code and shows the generic message', () async {
      final money = serviceWith(
        StubAdapter(409, {
          'code': 'WALLET_FROZEN',
          'message': 'Server text the app never shows.',
          'correlationId': 'c-1',
        }),
      );
      await expectLater(
        money.resolveRecipient('omar@raad.test'),
        throwsA(
          isA<MoneyApiException>()
              .having((e) => e.code, 'code', 'WALLET_FROZEN')
              .having((e) => e.status, 'status', 409)
              .having((e) => e.correlationId, 'correlationId', 'c-1')
              .having(Messages.forMoneyError, 'message', Messages.generic),
        ),
      );
    });

    test(
      'a read is not retried after 429 or 503, but once after 500',
      () async {
        for (final (status, code, calls) in [
          (429, 'RATE_LIMITED', 1),
          (503, 'SERVICE_UNAVAILABLE', 1),
          (500, 'INTERNAL_ERROR', 2),
        ]) {
          final stub = StubAdapter(status, {
            'code': code,
            'message': 'm',
            'correlationId': 'c',
          });
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

    test('a transfer is never retried, even after 500', () async {
      final stub = StubAdapter(500, {
        'code': 'INTERNAL_ERROR',
        'message': 'm',
        'correlationId': 'c',
      });
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

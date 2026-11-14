/// A contract fake of the Money API (C1), for tests and the offline preview.
///
/// It plugs into Dio below the generated client, so every request and answer
/// crosses the same wire shapes as the real service: status codes, the flat
/// `Error` body with top-level `code`, `message` and `correlationId`, and the
/// response nesting of the pinned OpenAPI file. A contract test checks its
/// answers against that file's schemas.
///
/// It models the U1 walking-skeleton subset only. Like the U1 service, it
/// checks the `Idempotency-Key` header but does not store or replay earlier
/// outcomes, and it serves the first history page only.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'fake_accounts.dart';

/// A failure the fake can be told to produce for the next matching call.
enum FakeFault {
  /// No answer within the client timeout; nothing happened on the server.
  timeout,

  /// The server answers 500 `INTERNAL_ERROR`; nothing happened.
  serverError,

  /// The server answers 503 `SERVICE_UNAVAILABLE`; nothing happened.
  unavailable,

  /// The transfer commits, then the answer is lost on the way back.
  lostResponseAfterCommit,

  /// The edge answers with a status C1 does not declare.
  undeclaredStatus,
}

/// One request the fake received, kept for test assertions. Token values
/// are not kept.
final class FakeRequest {
  const FakeRequest({
    required this.method,
    required this.path,
    required this.hasBearer,
    required this.idempotencyKey,
    required this.body,
  });

  final String method;
  final String path;
  final bool hasBearer;
  final String? idempotencyKey;
  final Object? body;

  String get operation => '$method $path';
}

final class _Wallet {
  _Wallet(this.owner, this.balanceHalalas);

  final FakeAccount owner;
  int balanceHalalas;
}

final class _Transfer {
  const _Transfer({
    required this.transferId,
    required this.reference,
    required this.sender,
    required this.recipient,
    required this.amountHalalas,
    required this.completedAt,
  });

  final String transferId;
  final String reference;
  final FakeAccount sender;
  final FakeAccount recipient;
  final int amountHalalas;
  final DateTime completedAt;
}

final class FakeMoneyBackend implements HttpClientAdapter {
  FakeMoneyBackend({this._accounts = fakeAccounts, DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  /// The offline preview: Omar already has a wallet, so Sara can send to him.
  factory FakeMoneyBackend.preview() =>
      FakeMoneyBackend()..openWallet(fakeOmar);

  static const int openingBalanceHalalas = 100000;
  static const int minTransferHalalas = 100;
  static const int maxTransferHalalas = 50000;
  static const String basePath = '/money/v1';
  static const String baseUrl = 'https://money.fake.raad.local$basePath';

  static final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9._~-]+$');

  final List<FakeAccount> _accounts;
  final DateTime Function() _now;
  final Map<String, _Wallet> _wallets = {};
  final List<_Transfer> _transfers = [];
  final Map<String, FakeFault> _faults = {};
  final List<FakeRequest> requests = [];
  final Uuid _uuid = const Uuid();
  int _correlation = 0;
  int _referenceCounter = 0;

  /// When set, `POST /transfers` waits for it before answering.
  Completer<void>? transferGate;

  // ---------------------------------------------------------------- setup

  /// Opens a wallet directly, as if the account had already set one up.
  void openWallet(
    FakeAccount account, {
    int balanceHalalas = openingBalanceHalalas,
  }) {
    _wallets[account.sub] = _Wallet(account, balanceHalalas);
  }

  int? balanceOf(FakeAccount account) => _wallets[account.sub]?.balanceHalalas;

  /// Changes a balance directly, as if money had moved elsewhere.
  void setBalance(FakeAccount account, int halalas) =>
      _wallets[account.sub]!.balanceHalalas = halalas;

  /// Removes a wallet, to exercise the app's `WALLET_NOT_FOUND` handling.
  void forgetWallet(FakeAccount account) => _wallets.remove(account.sub);

  /// Adds a completed transfer to history without changing balances.
  void seedTransfer({
    required FakeAccount sender,
    required FakeAccount recipient,
    required int amountHalalas,
    required DateTime completedAt,
    String? reference,
  }) {
    _transfers.add(
      _Transfer(
        transferId: _uuid.v4(),
        reference: reference ?? _nextReference(),
        sender: sender,
        recipient: recipient,
        amountHalalas: amountHalalas,
        completedAt: completedAt.toUtc(),
      ),
    );
  }

  /// Makes the next call to [operation] (for example `POST /transfers`)
  /// fail with [fault].
  void failNext(String operation, FakeFault fault) =>
      _faults[operation] = fault;

  int countOf(String operation) =>
      requests.where((request) => request.operation == operation).length;

  // ------------------------------------------------------------ transport

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.startsWith(basePath)
        ? options.uri.path.substring(basePath.length)
        : options.uri.path;
    final method = options.method.toUpperCase();
    final body = await _readBody(requestStream);
    final authorization = _header(options, 'authorization');
    final idempotencyKey = _header(options, 'idempotency-key');
    final request = FakeRequest(
      method: method,
      path: path,
      hasBearer: authorization?.startsWith('Bearer ') ?? false,
      idempotencyKey: idempotencyKey,
      body: body,
    );
    requests.add(request);

    final fault = _faults.remove(request.operation);
    switch (fault) {
      case FakeFault.timeout:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      case FakeFault.serverError:
        return _error(500, 'INTERNAL_ERROR', 'Something went wrong.');
      case FakeFault.unavailable:
        return _error(
          503,
          'SERVICE_UNAVAILABLE',
          'The service is unavailable.',
          headers: {
            'retry-after': ['2'],
          },
        );
      case FakeFault.undeclaredStatus:
        return ResponseBody.fromString('Bad gateway', 502);
      case FakeFault.lostResponseAfterCommit:
      case null:
        break;
    }

    final caller = _caller(authorization);
    if (caller == null) {
      return _error(401, 'AUTHENTICATION_REQUIRED', 'Sign in again.');
    }
    final response = switch (request.operation) {
      'PUT /wallet' => _ensureWallet(caller),
      'GET /wallet' => _getWallet(caller),
      'POST /recipients/resolve' => _resolve(caller, body),
      'POST /transfers' => await _transfer(caller, body, idempotencyKey),
      'GET /transfers' => _list(caller, options.uri.queryParameters),
      _ => _error(404, 'VALIDATION_ERROR', 'Unknown route.'),
    };
    if (fault == FakeFault.lostResponseAfterCommit) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return response;
  }

  @override
  void close({bool force = false}) {}

  // ------------------------------------------------------------ operations

  ResponseBody _ensureWallet(FakeAccount caller) {
    final existing = _wallets[caller.sub];
    if (existing != null) return _json(200, _walletJson(existing));
    final wallet = _Wallet(caller, openingBalanceHalalas);
    _wallets[caller.sub] = wallet;
    return _json(201, _walletJson(wallet));
  }

  ResponseBody _getWallet(FakeAccount caller) {
    final wallet = _wallets[caller.sub];
    if (wallet == null) {
      return _error(404, 'WALLET_NOT_FOUND', 'Set up your wallet first.');
    }
    return _json(200, _walletJson(wallet));
  }

  ResponseBody _resolve(FakeAccount caller, Object? body) {
    if (body is! Map<String, Object?> ||
        body.keys.any((key) => key != 'email') ||
        body['email'] is! String ||
        (body['email']! as String).length > 512) {
      return _error(400, 'VALIDATION_ERROR', 'Check the request.');
    }
    final email = _normalize(body['email']! as String);
    if (!_validEmail(email)) {
      return _error(400, 'VALIDATION_ERROR', 'Enter a complete email address.');
    }
    final recipient = _holderOf(email);
    if (recipient == null) {
      return _error(
        404,
        'RECIPIENT_NOT_FOUND',
        'No recipient has that address.',
      );
    }
    if (recipient.sub == caller.sub) {
      return _error(409, 'SELF_TRANSFER', 'You cannot send to yourself.');
    }
    return _json(200, _recipientJson(recipient));
  }

  Future<ResponseBody> _transfer(
    FakeAccount caller,
    Object? body,
    String? idempotencyKey,
  ) async {
    final gate = transferGate;
    if (gate != null) await gate.future;
    if (idempotencyKey == null ||
        idempotencyKey.length < 16 ||
        idempotencyKey.length > 128 ||
        !_keyPattern.hasMatch(idempotencyKey)) {
      return _error(400, 'VALIDATION_ERROR', 'Check the request.');
    }
    if (body is! Map<String, Object?> ||
        body.keys.any(
          (key) => key != 'recipientEmail' && key != 'amountHalalas',
        ) ||
        body['recipientEmail'] is! String ||
        (body['recipientEmail']! as String).length > 512 ||
        body['amountHalalas'] is! int) {
      return _error(400, 'VALIDATION_ERROR', 'Check the request.');
    }
    final email = _normalize(body['recipientEmail']! as String);
    final amount = body['amountHalalas']! as int;
    if (!_validEmail(email)) {
      return _error(400, 'VALIDATION_ERROR', 'Enter a complete email address.');
    }
    final senderWallet = _wallets[caller.sub];
    if (senderWallet == null) {
      return _error(404, 'WALLET_NOT_FOUND', 'Set up your wallet first.');
    }
    const replayed = {
      'idempotency-replayed': ['false'],
    };
    final recipient = _holderOf(email);
    if (recipient == null) {
      return _error(
        404,
        'RECIPIENT_NOT_FOUND',
        'No recipient has that address.',
        headers: replayed,
      );
    }
    if (amount < minTransferHalalas || amount > maxTransferHalalas) {
      return _error(
        422,
        'AMOUNT_OUT_OF_RANGE',
        'The amount is out of range.',
        headers: replayed,
      );
    }
    if (recipient.sub == caller.sub) {
      return _error(
        409,
        'SELF_TRANSFER',
        'You cannot send to yourself.',
        headers: replayed,
      );
    }
    if (senderWallet.balanceHalalas < amount) {
      return _error(
        422,
        'INSUFFICIENT_FUNDS',
        'The balance is too low.',
        headers: replayed,
      );
    }
    final recipientWallet = _wallets[recipient.sub]!;
    senderWallet.balanceHalalas -= amount;
    recipientWallet.balanceHalalas += amount;
    final transfer = _Transfer(
      transferId: _uuid.v4(),
      reference: _nextReference(),
      sender: caller,
      recipient: recipient,
      amountHalalas: amount,
      completedAt: _now(),
    );
    _transfers.add(transfer);
    return _json(201, {
      'transferId': transfer.transferId,
      'reference': transfer.reference,
      'recipient': _recipientJson(recipient),
      'amount': _moneyJson(amount),
      'completedAt': _instant(transfer.completedAt),
      'balanceAfter': _moneyJson(senderWallet.balanceHalalas),
    }, headers: replayed);
  }

  ResponseBody _list(FakeAccount caller, Map<String, String> query) {
    if (_wallets[caller.sub] == null) {
      return _error(404, 'WALLET_NOT_FOUND', 'Set up your wallet first.');
    }
    if (query.containsKey('cursor')) {
      return _error(400, 'CURSOR_INVALID_OR_EXPIRED', 'Reload the first page.');
    }
    final limit = int.tryParse(query['limit'] ?? '20');
    if (limit == null || limit < 1 || limit > 100) {
      return _error(400, 'VALIDATION_ERROR', 'Check the request.');
    }
    final mine =
        _transfers
            .where(
              (t) =>
                  t.sender.sub == caller.sub || t.recipient.sub == caller.sub,
            )
            .toList()
          ..sort((a, b) {
            final byTime = b.completedAt.compareTo(a.completedAt);
            return byTime != 0 ? byTime : b.transferId.compareTo(a.transferId);
          });
    final page = mine.take(limit).map((t) {
      final sent = t.sender.sub == caller.sub;
      return {
        'transferId': t.transferId,
        'reference': t.reference,
        'direction': sent ? 'sent' : 'received',
        'otherParty': _recipientJson(sent ? t.recipient : t.sender),
        'amount': _moneyJson(t.amountHalalas),
        'completedAt': _instant(t.completedAt),
      };
    }).toList();
    return _json(200, {
      'items': page,
      'nextCursor': mine.length > limit ? 'fake-opaque-cursor' : null,
    });
  }

  // --------------------------------------------------------------- helpers

  FakeAccount? _caller(String? authorization) {
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return null;
    }
    final token = authorization.substring('Bearer '.length);
    for (final account in _accounts) {
      if (account.token == token) return account;
    }
    return null;
  }

  FakeAccount? _holderOf(String normalizedEmail) {
    for (final wallet in _wallets.values) {
      if (wallet.owner.email == normalizedEmail) return wallet.owner;
    }
    return null;
  }

  static String _normalize(String email) => email.trim().toLowerCase();

  static bool _validEmail(String email) =>
      email.length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  String _nextReference() {
    _referenceCounter++;
    return 'RD-${_referenceCounter.toString().padLeft(6, '0')}';
  }

  static String _instant(DateTime time) => time.toUtc().toIso8601String();

  static Map<String, Object?> _moneyJson(int halalas) => {
    'amountHalalas': halalas,
    'currency': 'SAR',
  };

  static Map<String, Object?> _walletJson(_Wallet wallet) => {
    'balance': _moneyJson(wallet.balanceHalalas),
  };

  static Map<String, Object?> _recipientJson(FakeAccount account) => {
    'displayName': account.displayName,
    'email': account.email,
  };

  ResponseBody _error(
    int status,
    String code,
    String message, {
    Map<String, List<String>> headers = const {},
  }) {
    _correlation++;
    return _json(status, {
      'code': code,
      'message': message,
      'correlationId': 'fake-corr-$_correlation',
    }, headers: headers);
  }

  static ResponseBody _json(
    int status,
    Map<String, Object?> body, {
    Map<String, List<String>> headers = const {},
  }) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  static String? _header(RequestOptions options, String name) {
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value?.toString();
    }
    return null;
  }

  static Future<Object?> _readBody(Stream<Uint8List>? stream) async {
    if (stream == null) return null;
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return const _Malformed();
    }
  }
}

final class _Malformed {
  const _Malformed();
}

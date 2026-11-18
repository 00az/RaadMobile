/// A contract fake of the Money API (C1), for tests, the integration
/// journeys and the offline preview.
///
/// It plugs into Dio below the generated client, so every request and answer
/// crosses the same wire shapes as the real service: status codes, the flat
/// `Error` body with top-level `code`, `message` and `correlationId`, the
/// `Idempotency-Replayed` and `Retry-After` headers, and the response nesting
/// of the pinned OpenAPI file. A contract test checks its answers against
/// that file's schemas.
///
/// It follows U2's complete v1 behaviour (`1.0.0-u2.1`):
/// - `POST /transfers` saves the first business outcome of each
///   `(caller, Idempotency-Key)` and replays it for a repeat with the same
///   recipient and amount (`Idempotency-Replayed: true`); a repeat with other
///   details is `409 IDEMPOTENCY_KEY_REUSED` and changes nothing;
/// - the refusal order is unknown recipient, amount outside 100 to 50000
///   halalas, own wallet, balance too low; `400`, `401`, `403`,
///   `WALLET_NOT_FOUND`, `429`, `500` and `503` save nothing;
/// - history pages follow an opaque cursor bound to the caller, page size,
///   order, a snapshot taken at page one and a 24-hour expiry. Transfers made
///   after page one never shift its later pages. An altered, expired or
///   mismatched cursor is `400 CURSOR_INVALID_OR_EXPIRED`.
///
/// [failNext] and [answerNext] produce faults and edge answers, such as a
/// lost response or a rate limit.
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

  /// The connection dropped before the request reached the server.
  connectionLost,

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
    required this.query,
    required this.hasBearer,
    required this.idempotencyKey,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
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
    required this.sequence,
    required this.transferId,
    required this.reference,
    required this.sender,
    required this.recipient,
    required this.amountHalalas,
    required this.completedAt,
  });

  final int sequence;
  final String transferId;
  final String reference;
  final FakeAccount sender;
  final FakeAccount recipient;
  final int amountHalalas;
  final DateTime completedAt;
}

/// The saved first outcome of one `(caller, key)`.
final class _Outcome {
  const _Outcome(this.fingerprint, this.status, this.body);

  final String fingerprint;
  final int status;
  final Map<String, Object?> body;
}

/// An edge answer queued with [FakeMoneyBackend.answerNext].
final class _Answer {
  const _Answer(this.status, this.code, this.retryAfter);

  final int status;
  final String code;
  final int? retryAfter;
}

final class FakeMoneyBackend implements HttpClientAdapter {
  /// [directory] holds the accounts whose tokens it accepts; share it with
  /// the fake sign-in so a new sign-up can open a wallet.
  FakeMoneyBackend({FakeDirectory? directory, DateTime Function()? now})
    : _directory = directory ?? FakeDirectory(),
      _now = now ?? (() => DateTime.now().toUtc());

  /// The offline preview: Omar already has a wallet, so Sara can send to him.
  factory FakeMoneyBackend.preview({FakeDirectory? directory}) =>
      FakeMoneyBackend(directory: directory)..openWallet(fakeOmar);

  static const int openingBalanceHalalas = 100000;
  static const int minTransferHalalas = 100;
  static const int maxTransferHalalas = 50000;
  static const String basePath = '/money/v1';
  static const String baseUrl = 'https://money.fake.raad.local$basePath';
  static const Duration cursorLifetime = Duration(hours: 24);

  static final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9._~-]+$');
  static const String _referenceAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  final FakeDirectory _directory;
  final DateTime Function() _now;
  final Map<String, _Wallet> _wallets = {};
  final List<_Transfer> _transfers = [];
  final Map<String, _Outcome> _outcomes = {};
  final Map<String, List<FakeFault>> _faults = {};
  final Map<String, _Answer> _answers = {};
  final List<FakeRequest> requests = [];
  final Uuid _uuid = const Uuid();
  int _correlation = 0;
  int _sequence = 0;

  /// When set, `POST /transfers` waits for it before answering.
  Completer<void>? transferGate;

  /// When set, `GET /transfers` waits for it before answering.
  Completer<void>? historyGate;

  final Map<String, Completer<void>> _holds = {};

  /// Holds the next call to [operation] until the returned completer is
  /// completed; the answer reflects the state at that moment. Used to make
  /// answers arrive out of order.
  Completer<void> hold(String operation) =>
      _holds[operation] = Completer<void>();

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
    _record(
      sender: sender,
      recipient: recipient,
      amountHalalas: amountHalalas,
      completedAt: completedAt.toUtc(),
      reference: reference,
    );
  }

  /// How many completed transfers moved money between these two people.
  int transfersBetween(FakeAccount sender, FakeAccount recipient) => _transfers
      .where(
        (t) => t.sender.sub == sender.sub && t.recipient.sub == recipient.sub,
      )
      .length;

  /// Makes the next [times] calls to [operation] (for example
  /// `POST /transfers`) fail with [fault]. A read's one permitted retry is
  /// a call of its own.
  void failNext(String operation, FakeFault fault, {int times = 1}) =>
      (_faults[operation] ??= []).addAll(List.filled(times, fault));

  /// Makes the next call to [operation] answer with this C1 error before
  /// any business rule runs, as the edge or a limit would. Nothing is saved.
  void answerNext(
    String operation,
    int status,
    String code, {
    int? retryAfterSeconds,
  }) => _answers[operation] = _Answer(status, code, retryAfterSeconds);

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
      query: Map.unmodifiable(options.uri.queryParameters),
      hasBearer: authorization?.startsWith('Bearer ') ?? false,
      idempotencyKey: idempotencyKey,
      body: body,
    );
    requests.add(request);
    final held = _holds.remove(request.operation);
    if (held != null) await held.future;

    final answer = _answers.remove(request.operation);
    if (answer != null) {
      return _error(
        answer.status,
        answer.code,
        'Refused by the test.',
        headers: {
          if (answer.retryAfter != null)
            'retry-after': ['${answer.retryAfter}'],
        },
      );
    }
    final queued = _faults[request.operation];
    final fault = queued == null || queued.isEmpty ? null : queued.removeAt(0);
    switch (fault) {
      case FakeFault.timeout:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      case FakeFault.connectionLost:
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
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
      'GET /transfers' => await _list(caller, request.query),
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

    final outcomeKey = '${caller.sub}\u0000$idempotencyKey';
    final fingerprint = 'v1|$email|$amount';
    final saved = _outcomes[outcomeKey];
    if (saved != null) {
      if (saved.fingerprint != fingerprint) {
        return _error(
          409,
          'IDEMPOTENCY_KEY_REUSED',
          'This key was used for another transfer.',
          headers: _replayed(false),
        );
      }
      return _json(saved.status, {
        ...saved.body,
        if (saved.status != 201) 'correlationId': _nextCorr(),
      }, headers: _replayed(true));
    }

    final (status, outcome) = _firstOutcome(
      caller,
      senderWallet,
      email,
      amount,
    );
    _outcomes[outcomeKey] = _Outcome(fingerprint, status, outcome);
    return _json(status, outcome, headers: _replayed(false));
  }

  /// Applies the business rules in C1's order and, when they all pass, moves
  /// the money in the same step that saves the outcome.
  (int, Map<String, Object?>) _firstOutcome(
    FakeAccount caller,
    _Wallet senderWallet,
    String email,
    int amount,
  ) {
    final recipient = _holderOf(email);
    if (recipient == null) {
      return (
        404,
        _errorJson('RECIPIENT_NOT_FOUND', 'No recipient has that address.'),
      );
    }
    if (amount < minTransferHalalas || amount > maxTransferHalalas) {
      return (
        422,
        _errorJson('AMOUNT_OUT_OF_RANGE', 'The amount is outside the limits.'),
      );
    }
    if (recipient.sub == caller.sub) {
      return (409, _errorJson('SELF_TRANSFER', 'You cannot send to yourself.'));
    }
    if (senderWallet.balanceHalalas < amount) {
      return (422, _errorJson('INSUFFICIENT_FUNDS', 'The balance is too low.'));
    }
    final recipientWallet = _wallets[recipient.sub]!;
    senderWallet.balanceHalalas -= amount;
    recipientWallet.balanceHalalas += amount;
    final transfer = _record(
      sender: caller,
      recipient: recipient,
      amountHalalas: amount,
      completedAt: _now(),
    );
    return (
      201,
      {
        'transferId': transfer.transferId,
        'reference': transfer.reference,
        'recipient': _recipientJson(recipient),
        'amount': _moneyJson(amount),
        'completedAt': _instant(transfer.completedAt),
        'balanceAfter': _moneyJson(senderWallet.balanceHalalas),
      },
    );
  }

  Future<ResponseBody> _list(
    FakeAccount caller,
    Map<String, String> query,
  ) async {
    final gate = historyGate;
    if (gate != null) await gate.future;
    if (_wallets[caller.sub] == null) {
      return _error(404, 'WALLET_NOT_FOUND', 'Set up your wallet first.');
    }
    final limit = int.tryParse(query['limit'] ?? '20');
    if (limit == null || limit < 1 || limit > 100) {
      return _error(400, 'VALIDATION_ERROR', 'Check the request.');
    }
    final now = _now();
    final _Cursor chain;
    final cursorText = query['cursor'];
    if (cursorText == null) {
      chain = _Cursor(
        sub: caller.sub,
        limit: limit,
        boundary: _sequence,
        expires: now.add(cursorLifetime),
      );
    } else {
      final decoded = _Cursor.decode(cursorText);
      if (decoded == null ||
          decoded.sub != caller.sub ||
          decoded.limit != limit ||
          !now.isBefore(decoded.expires)) {
        return _error(
          400,
          'CURSOR_INVALID_OR_EXPIRED',
          'Reload the first page.',
        );
      }
      chain = decoded;
    }
    final mine =
        _transfers
            .where(
              (t) =>
                  t.sequence <= chain.boundary &&
                  (t.sender.sub == caller.sub ||
                      t.recipient.sub == caller.sub) &&
                  chain.isAfterLast(t),
            )
            .toList()
          ..sort(_newestFirst);
    final page = mine.take(limit).toList();
    final more = mine.length > limit;
    final next = more ? chain.after(page.last).encode() : null;
    return _json(200, {
      'items': [
        for (final t in page)
          {
            'transferId': t.transferId,
            'reference': t.reference,
            'direction': t.sender.sub == caller.sub ? 'sent' : 'received',
            'otherParty': _recipientJson(
              t.sender.sub == caller.sub ? t.recipient : t.sender,
            ),
            'amount': _moneyJson(t.amountHalalas),
            'completedAt': _instant(t.completedAt),
          },
      ],
      'nextCursor': next,
      'hasMore': next != null,
    });
  }

  // --------------------------------------------------------------- helpers

  _Transfer _record({
    required FakeAccount sender,
    required FakeAccount recipient,
    required int amountHalalas,
    required DateTime completedAt,
    String? reference,
  }) {
    _sequence++;
    final transfer = _Transfer(
      sequence: _sequence,
      transferId: _uuid.v4(),
      reference: reference ?? _referenceFor(_sequence),
      sender: sender,
      recipient: recipient,
      amountHalalas: amountHalalas,
      completedAt: completedAt,
    );
    _transfers.add(transfer);
    return transfer;
  }

  /// `R-` and 12 characters from U2's alphabet, counting up from
  /// `R-222222222223`.
  static String _referenceFor(int number) {
    final base = _referenceAlphabet.length;
    final chars = List.filled(12, _referenceAlphabet[0]);
    var rest = number;
    for (var i = 11; i >= 0 && rest > 0; i--) {
      chars[i] = _referenceAlphabet[rest % base];
      rest ~/= base;
    }
    return 'R-${chars.join()}';
  }

  static int _newestFirst(_Transfer a, _Transfer b) {
    final byTime = b.completedAt.compareTo(a.completedAt);
    return byTime != 0 ? byTime : b.transferId.compareTo(a.transferId);
  }

  FakeAccount? _caller(String? authorization) {
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return null;
    }
    return _directory.byToken(authorization.substring('Bearer '.length));
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

  static Map<String, List<String>> _replayed(bool replayed) => {
    'idempotency-replayed': ['$replayed'],
  };

  String _nextCorr() => 'fake-corr-${++_correlation}';

  Map<String, Object?> _errorJson(String code, String message) => {
    'code': code,
    'message': message,
    'correlationId': _nextCorr(),
  };

  ResponseBody _error(
    int status,
    String code,
    String message, {
    Map<String, List<String>> headers = const {},
  }) => _json(status, _errorJson(code, message), headers: headers);

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

/// The fake's history cursor. The app only ever sees it as an opaque string;
/// the checksum makes any change to it detectable, as U2's signed cursor is.
final class _Cursor {
  const _Cursor({
    required this.sub,
    required this.limit,
    required this.boundary,
    required this.expires,
    this.lastCompletedAt,
    this.lastTransferId,
  });

  final String sub;
  final int limit;

  /// The last transfer sequence number visible to this chain (the snapshot
  /// taken when page one was issued).
  final int boundary;
  final DateTime expires;
  final DateTime? lastCompletedAt;
  final String? lastTransferId;

  _Cursor after(_Transfer last) => _Cursor(
    sub: sub,
    limit: limit,
    boundary: boundary,
    expires: expires,
    lastCompletedAt: last.completedAt,
    lastTransferId: last.transferId,
  );

  /// True when [t] sorts after the last row this chain returned.
  bool isAfterLast(_Transfer t) {
    final time = lastCompletedAt;
    final id = lastTransferId;
    if (time == null || id == null) return true;
    final byTime = t.completedAt.compareTo(time);
    if (byTime != 0) return byTime < 0;
    return t.transferId.compareTo(id) < 0;
  }

  String encode() {
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          's': sub,
          'l': limit,
          'b': boundary,
          'e': expires.toUtc().toIso8601String(),
          't': lastCompletedAt?.toUtc().toIso8601String(),
          'i': lastTransferId,
        }),
      ),
    );
    return '$payload.${_checksum(payload)}';
  }

  static _Cursor? decode(String text) {
    final dot = text.lastIndexOf('.');
    if (dot <= 0) return null;
    final payload = text.substring(0, dot);
    if (text.substring(dot + 1) != _checksum(payload)) return null;
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(payload)),
      ) as Map<String, Object?>;
      final time = json['t'];
      return _Cursor(
        sub: json['s']! as String,
        limit: json['l']! as int,
        boundary: json['b']! as int,
        expires: DateTime.parse(json['e']! as String),
        lastCompletedAt: time is String ? DateTime.parse(time) : null,
        lastTransferId: json['i'] as String?,
      );
    } on Object {
      return null;
    }
  }

  /// FNV-1a over the payload with a fixed salt: enough to show tampering in
  /// a fake. The real service signs its cursor.
  static String _checksum(String payload) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode('raad-fake-cursor|$payload')) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

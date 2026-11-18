/// The app's view of the Money API (contract C1, pinned at U2's
/// `1.0.0-u2.1`), built on the client generated from the pinned OpenAPI file.
///
/// Screens never see HTTP. They get the generated models back, or one of two
/// failures:
/// - [MoneyApiException]: a definite answer the app can act on, carrying the
///   top-level `code` from the C1 `Error` body.
/// - [TransferOutcomeUnknown]: a transfer whose result the app cannot know
///   (timeout, lost response or server failure). It is never sent again
///   automatically; only the person's own **Try again**, with the same
///   `Idempotency-Key` and the same details, may send it again, because U2
///   replays the first outcome of a repeated key.
library;

import 'dart:math';

import 'package:dio/dio.dart';

import '../auth/auth_service.dart';
import 'generated/money_api_client.dart';

/// Error codes the app branches on, as spelled in C1.
abstract final class MoneyErrorCode {
  static final String validation = Error2CodeValue.validationError.value;
  static final String authenticationRequired =
      Error2CodeValue.authenticationRequired.value;
  static final String forbidden = Error2CodeValue.forbidden.value;
  static final String walletNotFound = Error2CodeValue.walletNotFound.value;
  static final String recipientNotFound =
      Error2CodeValue.recipientNotFound.value;
  static final String selfTransfer = Error2CodeValue.selfTransfer.value;
  static final String amountOutOfRange = Error2CodeValue.amountOutOfRange.value;
  static final String insufficientFunds =
      Error2CodeValue.insufficientFunds.value;
  static final String idempotencyKeyReused =
      Error2CodeValue.idempotencyKeyReused.value;
  static final String cursorInvalidOrExpired =
      Error2CodeValue.cursorInvalidOrExpired.value;
  static final String rateLimited = Error2CodeValue.rateLimited.value;
  static final String serviceUnavailable =
      Error2CodeValue.serviceUnavailable.value;

  /// App-side codes for failures that carry no C1 body.
  static const String network = 'NETWORK_ERROR';
  static const String unexpectedResponse = 'UNEXPECTED_RESPONSE';
}

class MoneyApiException implements Exception {
  const MoneyApiException({
    required this.code,
    this.status,
    this.correlationId,
    this.retryAfter,
  });

  factory MoneyApiException.fromError(
    int? status,
    Error2 error, {
    Duration? retryAfter,
  }) => MoneyApiException(
    code: error.code.toJson(),
    status: status,
    correlationId: error.correlationId,
    retryAfter: retryAfter,
  );

  /// The top-level C1 `code`, a code this app version does not know yet, or
  /// one of the app-side codes in [MoneyErrorCode].
  final String code;
  final int? status;
  final String? correlationId;

  /// From the `Retry-After` header of a 429 or 503: how long to wait before
  /// the person may try again. The app never retries a 429 by itself.
  final Duration? retryAfter;

  bool get isAuthenticationRequired =>
      code == MoneyErrorCode.authenticationRequired || status == 401;

  bool get isRateLimited => code == MoneyErrorCode.rateLimited || status == 429;

  @override
  String toString() => 'MoneyApiException($code, status: $status)';
}

/// The transfer may or may not have happened.
class TransferOutcomeUnknown implements Exception {
  const TransferOutcomeUnknown();

  @override
  String toString() => 'TransferOutcomeUnknown';
}

/// Waits before a read is tried again; tests pass one that returns at once.
typedef RetryDelay = Future<void> Function(Duration wait);

/// Raised inside the request pipeline when there is no session to send.
final class _NoSession implements Exception {
  const _NoSession();
}

/// Carries the status and `Retry-After` of one HTTP answer out of the
/// generated client, which returns only the decoded body.
final class _Probe {
  static const String key = 'raad.responseProbe';

  int? status;
  Duration? retryAfter;

  Options options({Duration? receiveTimeout}) =>
      Options(extra: {key: this}, receiveTimeout: receiveTimeout);

  void capture(Response<Object?> response) {
    status = response.statusCode;
    final seconds = int.tryParse(
      response.headers.value('retry-after')?.trim() ?? '',
    );
    retryAfter = seconds != null && seconds > 0
        ? Duration(seconds: seconds)
        : null;
  }

  static void captureFrom(Response<Object?>? response) {
    final probe = response?.requestOptions.extra[key];
    if (probe is _Probe && response != null) probe.capture(response);
  }
}

final class MoneyService {
  MoneyService(
    this._api, {
    RetryDelay? retryDelay,
    DateTime Function()? now,
    Random? random,
  }) : _delay = retryDelay ?? Future<void>.delayed,
       _now = now ?? DateTime.now,
       _random = random ?? Random();

  /// Builds the Dio pipeline the generated client runs on: the environment's
  /// base URL, the C1 timeouts and the bearer token. Nothing in it logs
  /// requests, responses or headers.
  factory MoneyService.create({
    required String baseUrl,
    required TokenSource auth,
    HttpClientAdapter? adapter,
    RetryDelay? retryDelay,
    DateTime Function()? now,
    Random? random,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        sendTimeout: deadline,
        receiveTimeout: deadline,
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors
      ..add(
        QueuedInterceptorsWrapper(
          onRequest: (options, handler) async {
            String? token;
            try {
              token = await auth.accessToken();
            } on AuthFailure catch (failure) {
              handler.reject(
                DioException(requestOptions: options, error: failure),
              );
              return;
            }
            if (token == null) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: const _NoSession(),
                ),
              );
              return;
            }
            options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          },
        ),
      )
      ..add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            _Probe.captureFrom(response);
            handler.next(response);
          },
          onError: (error, handler) {
            _Probe.captureFrom(error.response);
            handler.next(error);
          },
        ),
      );
    return MoneyService(
      MoneyApiClient(dio).api,
      retryDelay: retryDelay,
      now: now,
      random: random,
    );
  }

  /// C1's request deadline. A read and its one retry together stay inside it.
  static const Duration deadline = Duration(seconds: 15);

  /// Short enough that a connection that never opens leaves room in the
  /// deadline for the one permitted read retry.
  static const Duration connectTimeout = Duration(seconds: 5);

  /// The page size of a history chain: C1's default, and its maximum.
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  /// A retry is only started when at least this much of the deadline is left.
  static const Duration _minimumAttempt = Duration(seconds: 1);

  final ApiClient _api;
  final RetryDelay _delay;
  final DateTime Function() _now;
  final Random _random;

  /// `PUT /wallet`: opens the caller's wallet if it is missing, else returns
  /// it. Both 200 and 201 are success, and repeating it never credits the
  /// opening balance twice.
  Future<Money> ensureWallet() async {
    final (result, probe) = await _read(
      (options) => _api.ensureWallet(options: options),
    );
    return switch (result) {
      EnsureWallet200(:final value) ||
      EnsureWallet201(:final value) => value.balance,
      EnsureWallet401(:final value) ||
      EnsureWallet403(:final value) ||
      EnsureWallet409(:final value) ||
      EnsureWallet429(:final value) ||
      EnsureWallet500(:final value) ||
      EnsureWallet503(:final value) => throw _refusal(value, probe),
    };
  }

  /// `GET /wallet`. It never creates a wallet: a missing one is
  /// `WALLET_NOT_FOUND`, and the caller runs [ensureWallet].
  Future<Money> getBalance() async {
    final (result, probe) = await _read(
      (options) => _api.getWallet(options: options),
    );
    return switch (result) {
      GetWallet200(:final value) => value.balance,
      GetWallet401(:final value) ||
      GetWallet403(:final value) ||
      GetWallet404(:final value) ||
      GetWallet429(:final value) ||
      GetWallet500(:final value) ||
      GetWallet503(:final value) => throw _refusal(value, probe),
    };
  }

  /// `POST /recipients/resolve` for one complete email address.
  Future<Recipient> resolveRecipient(String email) async {
    final (result, probe) = await _read(
      (options) => _api.resolveRecipient(
        body: ResolveRecipientRequest(email: email),
        options: options,
      ),
    );
    return switch (result) {
      ResolveRecipient200(:final value) => value,
      ResolveRecipient400(:final value) ||
      ResolveRecipient401(:final value) ||
      ResolveRecipient403(:final value) ||
      ResolveRecipient404(:final value) ||
      ResolveRecipient409(:final value) ||
      ResolveRecipient429(:final value) ||
      ResolveRecipient500(:final value) ||
      ResolveRecipient503(:final value) => throw _refusal(value, probe),
    };
  }

  /// `GET /transfers`: one page of a history chain.
  ///
  /// The first page takes no [cursor]. Every later page passes the exact
  /// opaque `nextCursor` of the page before it, never parsed or changed, with
  /// the same [limit] that started the chain. `CURSOR_INVALID_OR_EXPIRED`
  /// means the chain must start again from page one.
  Future<TransferPage> historyPage({
    String? cursor,
    int limit = defaultPageSize,
  }) async {
    RangeError.checkValueInInterval(limit, 1, maxPageSize, 'limit');
    final (result, probe) = await _read(
      (options) =>
          _api.listTransfers(cursor: cursor, limit: limit, options: options),
    );
    return switch (result) {
      ListTransfers200(:final value) => value,
      ListTransfers400(:final value) ||
      ListTransfers401(:final value) ||
      ListTransfers403(:final value) ||
      ListTransfers404(:final value) ||
      ListTransfers429(:final value) ||
      ListTransfers500(:final value) ||
      ListTransfers503(:final value) => throw _refusal(value, probe),
    };
  }

  /// `POST /transfers`. It is sent exactly once per call and never retried
  /// here.
  ///
  /// Throws [MoneyApiException] for a definite answer (a refusal U2 persisted
  /// as this key's first outcome, or one that persisted nothing) and
  /// [TransferOutcomeUnknown] when the outcome cannot be known: a timeout, a
  /// lost connection, a 500 or 503, an undeclared status or an unreadable
  /// success body.
  Future<TransferResult> createTransfer({
    required String recipientEmail,
    required int amountHalalas,
    required String idempotencyKey,
  }) async {
    final probe = _Probe();
    final CreateTransferResult result;
    try {
      result = await _api.createTransfer(
        idempotencyKey: idempotencyKey,
        body: CreateTransferRequest(
          recipientEmail: recipientEmail,
          amountHalalas: amountHalalas,
        ),
        options: probe.options(),
      );
    } on DioException catch (error) {
      final definite = _beforeSending(error);
      if (definite != null) throw definite;
      throw const TransferOutcomeUnknown();
    } on Object {
      // The server answered with a body this client cannot read.
      throw const TransferOutcomeUnknown();
    }
    return switch (result) {
      CreateTransfer201(:final value) => value,
      CreateTransfer400(:final value) ||
      CreateTransfer401(:final value) ||
      CreateTransfer403(:final value) ||
      CreateTransfer404(:final value) ||
      CreateTransfer409(:final value) ||
      CreateTransfer422(:final value) ||
      CreateTransfer429(:final value) => throw _refusal(value, probe),
      CreateTransfer500() ||
      CreateTransfer503() => throw const TransferOutcomeUnknown(),
    };
  }

  /// Runs a C1 read (or the wallet-setup `PUT`, which is safe to repeat).
  ///
  /// It is tried once more after a timeout, a 500 or a 503, after a short
  /// random pause (250 to 750 ms) or the `Retry-After` of a 503 when that is
  /// longer, and only while the 15-second deadline leaves room for it. A 429
  /// is never retried: the person decides when to try again.
  Future<(T, _Probe)> _read<T>(Future<T> Function(Options options) call) async {
    final started = _now();
    for (var attempt = 1; ; attempt++) {
      final probe = _Probe();
      final left = deadline - _now().difference(started);
      try {
        final result = await call(probe.options(receiveTimeout: left));
        final status = probe.status;
        if (attempt == 1 &&
            (status == 500 || status == 503) &&
            await _pauseForRetry(started, probe.retryAfter)) {
          continue;
        }
        return (result, probe);
      } on DioException catch (error) {
        final definite = _beforeSending(error);
        if (definite != null) throw definite;
        if (attempt == 1 &&
            _isTimeout(error) &&
            await _pauseForRetry(started, null)) {
          continue;
        }
        if (error.type == DioExceptionType.badResponse) {
          throw MoneyApiException(
            code: MoneyErrorCode.unexpectedResponse,
            status: error.response?.statusCode,
          );
        }
        throw const MoneyApiException(code: MoneyErrorCode.network);
      } on MoneyApiException {
        rethrow;
      } on Object {
        throw const MoneyApiException(code: MoneyErrorCode.unexpectedResponse);
      }
    }
  }

  Future<bool> _pauseForRetry(DateTime started, Duration? retryAfter) async {
    final jitter = Duration(milliseconds: 250 + _random.nextInt(501));
    final wait = retryAfter != null && retryAfter > jitter
        ? retryAfter
        : jitter;
    final left = deadline - _now().difference(started);
    if (wait + _minimumAttempt > left) return false;
    await _delay(wait);
    return true;
  }

  static MoneyApiException _refusal(Error2 error, _Probe probe) =>
      MoneyApiException.fromError(
        probe.status,
        error,
        retryAfter: probe.retryAfter,
      );

  /// A failure raised before the request left the phone: no session, or the
  /// token refresh could not reach the sign-in service.
  static MoneyApiException? _beforeSending(DioException error) {
    final cause = error.error;
    if (cause is _NoSession) {
      return MoneyApiException(code: MoneyErrorCode.authenticationRequired);
    }
    if (cause is AuthFailure) {
      return cause.code == AuthFailureCode.network
          ? const MoneyApiException(code: MoneyErrorCode.network)
          : MoneyApiException(code: MoneyErrorCode.authenticationRequired);
    }
    return null;
  }

  static bool _isTimeout(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout;
}

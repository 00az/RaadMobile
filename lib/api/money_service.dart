/// The app's view of the Money API (contract C1), built on the client
/// generated from the pinned OpenAPI file.
///
/// Screens never see HTTP. They get the generated models back, or one of two
/// failures:
/// - [MoneyApiException]: a definite answer the app can act on, carrying the
///   top-level `code` from the C1 `Error` body.
/// - [TransferOutcomeUnknown]: a transfer whose result the app cannot know
///   (timeout, lost response or server failure). The app must not send it
///   again; it reconciles with balance and history reads instead.
library;

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
  });

  factory MoneyApiException.fromError(int status, Error2 error) =>
      MoneyApiException(
        code: error.code.toJson(),
        status: status,
        correlationId: error.correlationId,
      );

  /// The top-level C1 `code`, a code this app version does not know yet, or
  /// one of the app-side codes in [MoneyErrorCode].
  final String code;
  final int? status;
  final String? correlationId;

  bool get isAuthenticationRequired =>
      code == MoneyErrorCode.authenticationRequired || status == 401;

  @override
  String toString() => 'MoneyApiException($code, status: $status)';
}

/// The transfer may or may not have happened.
class TransferOutcomeUnknown implements Exception {
  const TransferOutcomeUnknown();

  @override
  String toString() => 'TransferOutcomeUnknown';
}

/// Raised inside the request pipeline when there is no session to send.
final class _NoSession implements Exception {
  const _NoSession();
}

final class MoneyService {
  MoneyService(this._api);

  /// Builds the Dio pipeline the generated client runs on: the environment's
  /// base URL, the 15-second C1 timeout and the bearer token. Nothing in it
  /// logs requests, responses or headers.
  factory MoneyService.create({
    required String baseUrl,
    required AuthService auth,
    HttpClientAdapter? adapter,
  }) {
    const timeout = Duration(seconds: 15);
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(
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
              DioException(requestOptions: options, error: const _NoSession()),
            );
            return;
          }
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    return MoneyService(MoneyApiClient(dio).api);
  }

  final ApiClient _api;

  /// `PUT /wallet`: opens the caller's wallet if it is missing, else returns
  /// it. Both 200 and 201 are success.
  Future<Money> ensureWallet() async {
    final result = await _read(_api.ensureWallet);
    return switch (result) {
      EnsureWallet200(:final value) => value.balance,
      EnsureWallet201(:final value) => value.balance,
      EnsureWallet401(:final value) => throw MoneyApiException.fromError(
        401,
        value,
      ),
      EnsureWallet403(:final value) => throw MoneyApiException.fromError(
        403,
        value,
      ),
      EnsureWallet409(:final value) => throw MoneyApiException.fromError(
        409,
        value,
      ),
      EnsureWallet429(:final value) => throw MoneyApiException.fromError(
        429,
        value,
      ),
      EnsureWallet500(:final value) => throw MoneyApiException.fromError(
        500,
        value,
      ),
      EnsureWallet503(:final value) => throw MoneyApiException.fromError(
        503,
        value,
      ),
    };
  }

  /// `GET /wallet`. It never creates a wallet: a missing one is
  /// `WALLET_NOT_FOUND`, and the caller runs [ensureWallet].
  Future<Money> getBalance() async {
    final result = await _read(_api.getWallet);
    return switch (result) {
      GetWallet200(:final value) => value.balance,
      GetWallet401(:final value) => throw MoneyApiException.fromError(
        401,
        value,
      ),
      GetWallet403(:final value) => throw MoneyApiException.fromError(
        403,
        value,
      ),
      GetWallet404(:final value) => throw MoneyApiException.fromError(
        404,
        value,
      ),
      GetWallet429(:final value) => throw MoneyApiException.fromError(
        429,
        value,
      ),
      GetWallet500(:final value) => throw MoneyApiException.fromError(
        500,
        value,
      ),
      GetWallet503(:final value) => throw MoneyApiException.fromError(
        503,
        value,
      ),
    };
  }

  /// `POST /recipients/resolve` for one complete email address.
  Future<Recipient> resolveRecipient(String email) async {
    final result = await _read(
      () => _api.resolveRecipient(body: ResolveRecipientRequest(email: email)),
    );
    return switch (result) {
      ResolveRecipient200(:final value) => value,
      ResolveRecipient400(:final value) => throw MoneyApiException.fromError(
        400,
        value,
      ),
      ResolveRecipient401(:final value) => throw MoneyApiException.fromError(
        401,
        value,
      ),
      ResolveRecipient403(:final value) => throw MoneyApiException.fromError(
        403,
        value,
      ),
      ResolveRecipient404(:final value) => throw MoneyApiException.fromError(
        404,
        value,
      ),
      ResolveRecipient409(:final value) => throw MoneyApiException.fromError(
        409,
        value,
      ),
      ResolveRecipient429(:final value) => throw MoneyApiException.fromError(
        429,
        value,
      ),
      ResolveRecipient500(:final value) => throw MoneyApiException.fromError(
        500,
        value,
      ),
      ResolveRecipient503(:final value) => throw MoneyApiException.fromError(
        503,
        value,
      ),
    };
  }

  /// `GET /transfers`, first page only. U1 never follows `nextCursor`.
  Future<TransferPage> firstHistoryPage() async {
    final result = await _read(_api.listTransfers);
    return switch (result) {
      ListTransfers200(:final value) => value,
      ListTransfers400(:final value) => throw MoneyApiException.fromError(
        400,
        value,
      ),
      ListTransfers401(:final value) => throw MoneyApiException.fromError(
        401,
        value,
      ),
      ListTransfers403(:final value) => throw MoneyApiException.fromError(
        403,
        value,
      ),
      ListTransfers404(:final value) => throw MoneyApiException.fromError(
        404,
        value,
      ),
      ListTransfers429(:final value) => throw MoneyApiException.fromError(
        429,
        value,
      ),
      ListTransfers500(:final value) => throw MoneyApiException.fromError(
        500,
        value,
      ),
      ListTransfers503(:final value) => throw MoneyApiException.fromError(
        503,
        value,
      ),
    };
  }

  /// `POST /transfers`. It is sent exactly once per call and never retried
  /// here.
  ///
  /// Throws [MoneyApiException] for a definite refusal and
  /// [TransferOutcomeUnknown] when the outcome cannot be known: a timeout, a
  /// lost connection, a 500 or 503, an undeclared status or an unreadable
  /// success body.
  Future<TransferResult> createTransfer({
    required String recipientEmail,
    required int amountHalalas,
    required String idempotencyKey,
  }) async {
    final CreateTransferResult result;
    try {
      result = await _api.createTransfer(
        idempotencyKey: idempotencyKey,
        body: CreateTransferRequest(
          recipientEmail: recipientEmail,
          amountHalalas: amountHalalas,
        ),
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
      CreateTransfer400(:final value) => throw MoneyApiException.fromError(
        400,
        value,
      ),
      CreateTransfer401(:final value) => throw MoneyApiException.fromError(
        401,
        value,
      ),
      CreateTransfer403(:final value) => throw MoneyApiException.fromError(
        403,
        value,
      ),
      CreateTransfer404(:final value) => throw MoneyApiException.fromError(
        404,
        value,
      ),
      CreateTransfer409(:final value) => throw MoneyApiException.fromError(
        409,
        value,
      ),
      CreateTransfer422(:final value) => throw MoneyApiException.fromError(
        422,
        value,
      ),
      CreateTransfer429(:final value) => throw MoneyApiException.fromError(
        429,
        value,
      ),
      CreateTransfer500() => throw const TransferOutcomeUnknown(),
      CreateTransfer503() => throw const TransferOutcomeUnknown(),
    };
  }

  /// Runs a safe read, retrying once after a timeout or a 500 as C1 allows.
  /// A 429 or 503 is not retried here, so `Retry-After` is always respected.
  Future<T> _read<T>(Future<T> Function() call) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final result = await call();
        if (attempt == 1 && _isServerError(result)) continue;
        return result;
      } on DioException catch (error) {
        final definite = _beforeSending(error);
        if (definite != null) throw definite;
        if (attempt == 1 && _isTimeout(error)) continue;
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

  static bool _isServerError(Object? result) =>
      result is EnsureWallet500 ||
      result is GetWallet500 ||
      result is ResolveRecipient500 ||
      result is ListTransfers500;
}

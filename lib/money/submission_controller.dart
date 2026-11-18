/// One transfer intent from review to its outcome (functional spec, "Money
/// Workflow and State Machine"; BR3.4):
///
/// ```text
/// draft -> review -> submitting -> completed | businessRefused | uncertain
/// review -> draft (cancel, no request)
/// uncertain -> submitting (the person's Try again, same key and details)
/// uncertain -> draft (Change details: the old key is dropped)
/// ```
///
/// One `Idempotency-Key` is made at the first Confirm, saved with the locked
/// recipient and amount before anything is sent, and reused only by Try
/// again after an unknown outcome. Nothing here ever sends a transfer by
/// itself.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/generated/money_api_client.dart';
import '../api/money_service.dart';
import 'pending_transfer.dart';

enum SubmissionState {
  draft,
  review,
  submitting,
  completed,
  businessRefused,
  uncertain,
}

/// Why the controller is showing a note without changing the intent.
enum SubmissionNotice {
  /// The pending record could not be saved, so nothing was sent.
  notSaved,

  /// The wallet had to be set up first; Confirm again sends the same key.
  walletReady,

  /// The request could not leave the phone; nothing was sent.
  notSent,

  /// A limit refused this attempt; nothing was sent. See [retryAfter].
  rateLimited,

  /// The session ended. The intent stays saved for the same account.
  signInAgain,
}

/// What the person reviewed: who, how much, and the balance it came from.
final class ReviewedTransfer {
  const ReviewedTransfer({
    required this.recipientEmail,
    required this.recipientName,
    required this.recipientDisplayEmail,
    required this.amountHalalas,
    required this.balanceHalalas,
  });

  /// The normalized address that was looked up.
  final String recipientEmail;
  final String recipientName;
  final String recipientDisplayEmail;
  final int amountHalalas;
  final int balanceHalalas;

  int get projectedBalanceHalalas => balanceHalalas - amountHalalas;
}

class SubmissionController extends ChangeNotifier {
  SubmissionController({
    required this._money,
    required this._pending,
    required this.owner,
    required this.environment,
    DateTime Function()? now,
    String Function()? newKey,
  }) : _now = now ?? DateTime.now,
       _newKey = newKey ?? const Uuid().v4;

  /// Continues an unresolved intent found in protected storage after a
  /// restart or a new sign-in as the same account. It starts uncertain and
  /// sends nothing until the person chooses Try again.
  factory SubmissionController.restore(
    PendingTransfer record, {
    required MoneyService money,
    required PendingTransferStore pending,
    DateTime Function()? now,
  }) {
    final controller = SubmissionController(
      money: money,
      pending: pending,
      owner: record.owner,
      environment: record.environment,
      now: now,
    );
    controller
      .._reviewed = ReviewedTransfer(
        recipientEmail: record.recipientEmail,
        recipientName: record.recipientName,
        recipientDisplayEmail: record.recipientDisplayEmail,
        amountHalalas: record.amountHalalas,
        balanceHalalas: record.balanceBeforeHalalas,
      )
      .._record = record.withStatus(PendingStatus.uncertain)
      .._state = SubmissionState.uncertain;
    return controller;
  }

  final MoneyService _money;
  final PendingTransferStore _pending;
  final DateTime Function() _now;
  final String Function() _newKey;
  final String owner;
  final String environment;

  SubmissionState _state = SubmissionState.draft;
  ReviewedTransfer? _reviewed;
  PendingTransfer? _record;
  TransferResult? _result;
  MoneyApiException? _refusal;
  SubmissionNotice? _notice;
  Duration? _retryAfter;
  bool _checkHistoryFirst = false;

  SubmissionState get state => _state;
  ReviewedTransfer? get reviewed => _reviewed;
  TransferResult? get result => _result;

  /// The definite refusal behind [SubmissionState.businessRefused].
  MoneyApiException? get refusal => _refusal;
  SubmissionNotice? get notice => _notice;
  Duration? get retryAfter => _retryAfter;

  /// The key of the current intent, made at the first Confirm.
  String? get requestKey => _record?.requestKey;

  /// Set after the person dropped an uncertain intent: the send form asks
  /// them to look at their history before sending again.
  bool get checkHistoryFirst => _checkHistoryFirst;

  /// Opens review for [transfer]. No request is made.
  void review(ReviewedTransfer transfer) {
    if (_state != SubmissionState.draft &&
        _state != SubmissionState.businessRefused) {
      return;
    }
    _reviewed = transfer;
    _record = null;
    _refusal = null;
    _result = null;
    _set(SubmissionState.review);
  }

  /// Leaves review without sending anything. A record saved by an attempt
  /// the service never processed (wallet set-up, no connection) is dropped.
  void cancel() {
    if (_state != SubmissionState.review) return;
    if (_record != null) {
      _record = null;
      unawaited(_pending.clear(owner: owner, environment: environment));
    }
    _set(SubmissionState.draft);
  }

  /// The person's Confirm. A second tap while it runs does nothing.
  Future<void> confirm() async {
    if (_state != SubmissionState.review) return;
    await _send(from: SubmissionState.review);
  }

  /// The person's Try again after an unknown outcome: the same key, the same
  /// recipient and the same amount. U2 returns the first outcome if the
  /// earlier request did arrive.
  Future<void> tryAgain() async {
    if (_state != SubmissionState.uncertain) return;
    await _send(from: SubmissionState.uncertain);
  }

  /// The person drops an uncertain intent to change its details. The old
  /// key is never sent again; the next Confirm makes a new one.
  Future<void> changeDetails() async {
    if (_state != SubmissionState.uncertain) return;
    await _pending.clear(owner: owner, environment: environment);
    _record = null;
    _checkHistoryFirst = true;
    _set(SubmissionState.draft);
  }

  /// The person has looked at their history.
  void historyChecked() {
    if (!_checkHistoryFirst) return;
    _checkHistoryFirst = false;
    notifyListeners();
  }

  Future<void> _send({required SubmissionState from}) async {
    final reviewed = _reviewed!;
    // Taken synchronously, so a second tap finds the controller busy.
    _notice = null;
    _retryAfter = null;
    _set(SubmissionState.submitting);

    final record =
        _record ??
        PendingTransfer(
          requestKey: _newKey(),
          owner: owner,
          environment: environment,
          recipientEmail: reviewed.recipientEmail,
          recipientName: reviewed.recipientName,
          recipientDisplayEmail: reviewed.recipientDisplayEmail,
          amountHalalas: reviewed.amountHalalas,
          balanceBeforeHalalas: reviewed.balanceHalalas,
          createdAt: _now().toUtc(),
          status: PendingStatus.sending,
        );
    try {
      await _pending.save(record.withStatus(PendingStatus.sending));
    } on PendingTransferNotSaved {
      // Without the saved key nothing may be sent.
      _notice = SubmissionNotice.notSaved;
      _set(from);
      return;
    }
    _record = record;

    try {
      final result = await _money.createTransfer(
        recipientEmail: record.recipientEmail,
        amountHalalas: record.amountHalalas,
        idempotencyKey: record.requestKey,
      );
      await _resolve();
      _result = result;
      _set(SubmissionState.completed);
    } on TransferOutcomeUnknown {
      final uncertain = record.withStatus(PendingStatus.uncertain);
      _record = uncertain;
      try {
        await _pending.save(uncertain);
      } on PendingTransferNotSaved {
        // The record saved before sending already holds the key and details.
      }
      _set(SubmissionState.uncertain);
    } on MoneyApiException catch (error) {
      await _onRefused(error, from: from);
    }
  }

  Future<void> _onRefused(
    MoneyApiException error, {
    required SubmissionState from,
  }) async {
    if (_isSavedOutcome(error)) {
      // U2 saved this as the key's first outcome: the intent is settled.
      await _resolve();
      _refusal = error;
      _set(SubmissionState.businessRefused);
      return;
    }
    // Nothing was saved against the key for this attempt.
    if (from == SubmissionState.uncertain) {
      // The earlier request may still have gone through: stay uncertain.
      _notice = _noticeFor(error);
      _retryAfter = error.retryAfter;
      _set(SubmissionState.uncertain);
      return;
    }
    if (error.code == MoneyErrorCode.walletNotFound) {
      try {
        await _money.ensureWallet();
        _notice = SubmissionNotice.walletReady;
      } on MoneyApiException catch (setup) {
        await _resolve();
        _refusal = setup;
        _set(SubmissionState.businessRefused);
        return;
      }
      _set(SubmissionState.review);
      return;
    }
    if (error.code == MoneyErrorCode.network) {
      _notice = SubmissionNotice.notSent;
      _set(SubmissionState.review);
      return;
    }
    // A first attempt the service refused without saving anything (edge,
    // limit, validation or sign-in): the next attempt gets a new key.
    await _resolve();
    _refusal = error;
    _retryAfter = error.retryAfter;
    _notice = error.isAuthenticationRequired
        ? SubmissionNotice.signInAgain
        : null;
    _set(SubmissionState.businessRefused);
  }

  SubmissionNotice _noticeFor(MoneyApiException error) {
    if (error.isAuthenticationRequired) return SubmissionNotice.signInAgain;
    if (error.isRateLimited) return SubmissionNotice.rateLimited;
    return SubmissionNotice.notSent;
  }

  /// Codes U2 saves as the first outcome of a key, and replays.
  static bool _isSavedOutcome(MoneyApiException error) {
    final code = error.code;
    return code == MoneyErrorCode.recipientNotFound ||
        code == MoneyErrorCode.selfTransfer ||
        code == MoneyErrorCode.amountOutOfRange ||
        code == MoneyErrorCode.insufficientFunds ||
        code == MoneyErrorCode.idempotencyKeyReused;
  }

  Future<void> _resolve() async {
    _record = null;
    await _pending.clear(owner: owner, environment: environment);
  }

  void _set(SubmissionState state) {
    _state = state;
    notifyListeners();
  }
}

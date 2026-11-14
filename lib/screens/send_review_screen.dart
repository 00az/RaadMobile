import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../api/generated/money_api_client.dart';
import '../api/money_service.dart';
import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../money/halalas.dart';
import '../ui/messages.dart';
import 'send_result_screen.dart';

/// Returned to the send form when the transfer was definitely refused, so the
/// form can show why with the person's values still in place.
final class ReviewRefused {
  const ReviewRefused(this.message);

  final String message;
}

/// US3.2: review, then confirm or cancel.
///
/// Cancelling sends nothing (AC3.2.2). Confirm is disabled from the first tap
/// until the answer arrives. Each review is one transfer intent with its own
/// `Idempotency-Key`.
///
/// When the outcome cannot be known (timeout, lost answer, server failure)
/// the transfer is not sent again from here, by the app or by the person; the
/// screen sends them to the wallet, which re-reads balance and history.
class SendReviewScreen extends StatefulWidget {
  const SendReviewScreen({
    super.key,
    required this.recipient,
    required this.recipientEmail,
    required this.amountHalalas,
    required this.balanceHalalas,
  });

  final Recipient recipient;

  /// The normalized address the person entered and the lookup accepted.
  final String recipientEmail;
  final int amountHalalas;
  final int balanceHalalas;

  @override
  State<SendReviewScreen> createState() => _SendReviewScreenState();
}

class _SendReviewScreenState extends State<SendReviewScreen> {
  late final String _idempotencyKey = const Uuid().v4();
  bool _submitting = false;
  bool _outcomeUnknown = false;
  String? _notice;

  Future<void> _confirm() async {
    if (_submitting || _outcomeUnknown) return;
    setState(() {
      _submitting = true;
      _notice = null;
    });
    final services = AppServices.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await services.money.createTransfer(
        recipientEmail: widget.recipientEmail,
        amountHalalas: widget.amountHalalas,
        idempotencyKey: _idempotencyKey,
      );
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SendResultScreen(result: result),
        ),
      );
    } on TransferOutcomeUnknown {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _outcomeUnknown = true;
      });
    } on MoneyApiException catch (error) {
      if (!mounted) return;
      if (error.isAuthenticationRequired) {
        await showSignIn(context, notice: Messages.sessionExpired);
        return;
      }
      if (error.code == MoneyErrorCode.walletNotFound) {
        // Nothing was stored against the key, so after setup the same
        // request may be confirmed again with the same key.
        await _setUpWalletThenAskAgain(services);
        return;
      }
      navigator.pop(ReviewRefused(Messages.forMoneyError(error)));
    }
  }

  Future<void> _setUpWalletThenAskAgain(AppServices services) async {
    String notice;
    try {
      await services.money.ensureWallet();
      notice = Messages.walletReadyConfirmAgain;
    } on MoneyApiException catch (error) {
      notice = Messages.forMoneyError(error);
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _notice = notice;
    });
  }

  void _backToWallet() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projected = widget.balanceHalalas - widget.amountHalalas;
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review transfer'),
          automaticallyImplyLeading: !_submitting && !_outcomeUnknown,
          actions: const [EnvironmentChip()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _row('To', widget.recipient.displayName, 'review.name'),
              _row('Email', widget.recipient.email, 'review.email'),
              _row(
                'Amount',
                formatHalalas(widget.amountHalalas),
                'review.amount',
              ),
              _row(
                'Balance after',
                formatHalalas(projected),
                'review.projectedBalance',
              ),
              const SizedBox(height: 24),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_notice!, key: const ValueKey('review.notice')),
                ),
              if (_outcomeUnknown) ...[
                Text(
                  Messages.outcomeUnknownTitle,
                  key: const ValueKey('review.outcomeUnknown'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(Messages.outcomeUnknownBody),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('review.checkWallet'),
                  onPressed: _backToWallet,
                  child: const Text('Check my balance and history'),
                ),
              ] else ...[
                FilledButton(
                  key: const ValueKey('review.confirm'),
                  onPressed: _submitting ? null : _confirm,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm and send'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('review.cancel'),
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(child: Text(value, key: ValueKey(key))),
        ],
      ),
    );
  }
}

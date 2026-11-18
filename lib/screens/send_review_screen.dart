import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../l10n/app_localizations.dart';
import '../money/halalas.dart';
import '../money/submission_controller.dart';
import '../ui/formatting.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import '../widgets/status_banner.dart';
import 'send_result_screen.dart';

/// Returned by a restored review when the person chose Change details: the
/// values to put back in a new send form. The old key is already dropped.
final class ChangeDetails {
  const ChangeDetails({required this.email, required this.amount});

  final String email;
  final String amount;
}

/// S8: review, then confirm or cancel (US3.2, US3.6, US3.8, US3.9).
///
/// Cancel sends nothing (AC3.2.2). The first Confirm makes the one
/// `Idempotency-Key` of this intent and saves it before sending; a second
/// tap does nothing (AC3.6.3). A definite refusal goes back to the form with
/// the values kept. When the answer is lost the screen says the outcome is
/// unknown; only the person's own **Try again** sends again, with the same
/// key and details (AC3.8.2), and **Change details** drops that key.
class SendReviewScreen extends StatefulWidget {
  const SendReviewScreen({
    super.key,
    required this.controller,
    required this.balanceHalalas,
    this.restored = false,
  });

  final SubmissionController controller;

  /// The balance the wallet shows now.
  final int balanceHalalas;

  /// Opened from the wallet for an intent found after a restart, with no
  /// send form underneath.
  final bool restored;

  @override
  State<SendReviewScreen> createState() => _SendReviewScreenState();
}

class _SendReviewScreenState extends State<SendReviewScreen> {
  SubmissionController get _intent => widget.controller;

  @override
  void initState() {
    super.initState();
    _intent.addListener(_onIntent);
  }

  @override
  void dispose() {
    _intent.removeListener(_onIntent);
    super.dispose();
  }

  void _onIntent() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final session = AppServices.of(context).session;
    switch (_intent.state) {
      case SubmissionState.completed:
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SendResultScreen(result: _intent.result!),
          ),
        );
        return;
      case SubmissionState.businessRefused:
        if (_intent.notice == SubmissionNotice.signInAgain) {
          session.expire();
          return;
        }
        if (widget.restored) {
          setState(() {});
        } else {
          navigator.pop();
        }
        return;
      case SubmissionState.uncertain
          when _intent.notice == SubmissionNotice.signInAgain:
        // The intent stays saved; signing in again as the same account
        // brings it back.
        session.expire();
        return;
      case _:
        setState(() {});
    }
  }

  void _backToWallet() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Drops the old key. From the send form, Back returns to it with the
  /// values kept; for a restored intent the wallet opens the form with them.
  Future<void> _changeDetails() async {
    final navigator = Navigator.of(context);
    final reviewed = _intent.reviewed!;
    await _intent.changeDetails();
    if (!mounted) return;
    navigator.pop(
      widget.restored
          ? ChangeDetails(
              email: reviewed.recipientEmail,
              amount: formatHalalas(
                reviewed.amountHalalas,
                withCurrency: false,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _intent.state;
    final submitting = state == SubmissionState.submitting;
    final uncertain = state == SubmissionState.uncertain;
    return PopScope(
      // While sending, Back does nothing. After an unknown outcome the
      // transfer may already have gone through, so Back goes to the wallet,
      // never to a filled form that could send it again with a new key.
      canPop: !submitting && !uncertain,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _intent.cancel();
        } else if (uncertain) {
          _backToWallet();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reviewTitle),
          automaticallyImplyLeading: !submitting && !uncertain,
          actions: const [EnvironmentChip()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              _summary(l10n),
              const SizedBox(height: 24),
              if (_noticeText(l10n) case final notice?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusBanner(
                    kind: StatusKind.info,
                    text: notice,
                    textKey: const ValueKey('review.notice'),
                  ),
                ),
              if (state == SubmissionState.businessRefused &&
                  _intent.refusal != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusBanner(
                    kind: StatusKind.error,
                    text: Messages.forMoneyError(l10n, _intent.refusal!),
                    textKey: const ValueKey('review.refusal'),
                  ),
                ),
              const SendingNeedsConnection(textKey: ValueKey('review.offline')),
              if (uncertain)
                ..._uncertain(l10n)
              else if (state == SubmissionState.businessRefused)
                FilledButton(
                  key: const ValueKey('review.close'),
                  onPressed: _backToWallet,
                  child: Text(l10n.resultDone),
                )
              else
                ..._confirm(l10n, submitting: submitting),
            ],
          ),
        ),
      ),
    );
  }

  String? _noticeText(AppLocalizations l10n) {
    return switch (_intent.notice) {
      SubmissionNotice.walletReady => l10n.reviewWalletReady,
      SubmissionNotice.notSent => l10n.reviewNotSent,
      SubmissionNotice.notSaved => l10n.reviewNotSaved,
      SubmissionNotice.rateLimited => Messages.rateLimited(
        l10n,
        _intent.retryAfter,
      ),
      SubmissionNotice.signInAgain || null => null,
    };
  }

  Widget _summary(AppLocalizations l10n) {
    final formats = Formats.of(context);
    final reviewed = _intent.reviewed!;
    return Column(
      children: [
        Center(
          child: ExcludeSemantics(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: RaadColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: RaadColors.cyanAccent, width: 2),
                boxShadow: const [
                  BoxShadow(color: RaadColors.cyanGlow, blurRadius: 20),
                ],
              ),
              child: Center(
                child: Text(
                  reviewed.recipientName.isNotEmpty
                      ? reviewed.recipientName.characters.first.toUpperCase()
                      : 'R',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: RaadColors.cyanAccent,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RaadColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RaadColors.cardBorder),
          ),
          child: Column(
            children: [
              _row(l10n.reviewTo, reviewed.recipientName, 'review.name'),
              const Divider(color: RaadColors.cardBorder, height: 20),
              _row(
                l10n.reviewEmail,
                formats.ltr(reviewed.recipientDisplayEmail),
                'review.email',
              ),
              const Divider(color: RaadColors.cardBorder, height: 20),
              _row(
                l10n.reviewAmount,
                formats.money(reviewed.amountHalalas),
                'review.amount',
                isHighlight: true,
              ),
              const Divider(color: RaadColors.cardBorder, height: 20),
              _row(
                l10n.reviewBalanceAfter,
                formats.money(reviewed.projectedBalanceHalalas),
                'review.projectedBalance',
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _confirm(AppLocalizations l10n, {required bool submitting}) {
    return [
      ConnectionBuilder(
        builder: (context, online) => FilledButton(
          key: const ValueKey('review.confirm'),
          onPressed: submitting || !online ? null : _intent.confirm,
          child: submitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RaadColors.background,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(l10n.reviewSending),
                      ),
                    ),
                  ],
                )
              : Text(l10n.reviewConfirm),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(
        key: const ValueKey('review.cancel'),
        onPressed: submitting ? null : () => Navigator.of(context).maybePop(),
        child: Text(l10n.reviewCancel),
      ),
    ];
  }

  /// AC3.8.1: the outcome is unknown. Nothing is sent again automatically.
  List<Widget> _uncertain(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return [
      Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.help_outline_rounded,
                color: RaadColors.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.transferUnconfirmedTitle,
                key: const ValueKey('review.outcomeUnknown'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.transferUnconfirmedBody,
        style: const TextStyle(color: RaadColors.textSecondary),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey('review.checkWallet'),
        onPressed: _backToWallet,
        child: Text(l10n.uncertainCheck),
      ),
      const SizedBox(height: 10),
      ConnectionBuilder(
        builder: (context, online) => OutlinedButton(
          key: const ValueKey('review.tryAgain'),
          onPressed: online ? _intent.tryAgain : null,
          child: Text(l10n.uncertainTryAgain),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          l10n.uncertainTryAgainNote,
          style: const TextStyle(color: RaadColors.textSecondary, fontSize: 12),
        ),
      ),
      TextButton(
        key: const ValueKey('review.changeDetails'),
        onPressed: _changeDetails,
        child: Text(l10n.uncertainChangeDetails),
      ),
    ];
  }

  Widget _row(
    String label,
    String value,
    String key, {
    bool isHighlight = false,
  }) {
    return MergeSemantics(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: RaadColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            key: ValueKey(key),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isHighlight
                  ? RaadColors.cyanAccent
                  : RaadColors.textPrimary,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              fontSize: isHighlight ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

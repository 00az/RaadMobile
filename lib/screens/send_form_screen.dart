import 'package:flutter/material.dart';

import '../api/money_service.dart';
import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../dev/fake_accounts.dart';
import '../l10n/app_localizations.dart';
import '../money/halalas.dart';
import '../money/submission_controller.dart';
import '../ui/formatting.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import '../widgets/status_banner.dart';
import 'history_screen.dart';
import 'send_review_screen.dart';

/// S7: recipient and amount, then the recipient lookup (US3.1, US3.3 to
/// US3.5, US3.9).
///
/// Amounts are checked as whole halalas from 1.00 to 500.00 SAR before any
/// request; the Money API stays the authority. Every refusal keeps what the
/// person typed (AC3.3.4, AC3.4.3). Without a connection Continue is off and
/// says why; it turns on again when the connection returns, and nothing is
/// ever queued.
class SendFormScreen extends StatefulWidget {
  const SendFormScreen({
    super.key,
    required this.balanceHalalas,
    this.controller,
    this.initialEmail = '',
    this.initialAmount = '',
  });

  final int balanceHalalas;

  /// An intent dropped with Change details on a restored transfer; its
  /// history reminder carries over.
  final SubmissionController? controller;
  final String initialEmail;
  final String initialAmount;

  @override
  State<SendFormScreen> createState() => _SendFormScreenState();
}

/// Where a refusal is shown on the form.
enum _Field { email, amount, banner }

class _SendFormScreenState extends State<SendFormScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  late final _amount = TextEditingController(text: widget.initialAmount);
  SubmissionController? _controller;
  String? _emailError;
  String? _amountError;
  String? _error;
  bool _busy = false;

  SubmissionController get _intent => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final services = AppServices.of(context);
    _controller =
        widget.controller ??
        SubmissionController(
          money: services.money,
          pending: services.pendingTransfers,
          owner: services.session.accountId ?? '',
          environment: services.environmentName,
          now: services.now,
        );
    _intent.addListener(_onIntent);
  }

  @override
  void dispose() {
    _intent.removeListener(_onIntent);
    if (widget.controller == null) _intent.dispose();
    _email.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onIntent() {
    if (mounted) setState(() {});
  }

  void _clearErrors() {
    if (_emailError == null && _amountError == null && _error == null) return;
    setState(() {
      _emailError = null;
      _amountError = null;
      _error = null;
    });
  }

  Future<void> _openHistory() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen()));
    _intent.historyChecked();
  }

  void _fillAmount(String value) {
    setState(() {
      _amount.text = value;
      _amountError = null;
      _error = null;
    });
  }

  Future<void> _continue() async {
    final services = AppServices.of(context);
    if (_busy || !services.connectivity.isOnline) return;
    final l10n = AppLocalizations.of(context);
    final email = normalizeEmail(_email.text);
    final amount = checkTransferAmount(
      _amount.text,
      balanceHalalas: widget.balanceHalalas,
    );
    final emailError = email.isEmpty
        ? l10n.sendEmailRequired
        : (looksLikeEmail(email) ? null : l10n.sendEmailInvalid);
    final amountError = switch (amount.problem) {
      null => null,
      AmountProblem.empty => l10n.sendAmountRequired,
      AmountProblem.notANumber => l10n.sendAmountInvalid,
      AmountProblem.outOfRange => l10n.amountRange,
      AmountProblem.insufficientBalance => l10n.balanceLow,
    };
    setState(() {
      _emailError = emailError;
      _amountError = amountError;
      _error = null;
    });
    if (emailError != null || amountError != null) return;

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final recipient = await services.money.resolveRecipient(email);
      if (!mounted) return;
      setState(() => _busy = false);
      _intent.review(
        ReviewedTransfer(
          recipientEmail: email,
          recipientName: recipient.displayName,
          recipientDisplayEmail: recipient.email,
          amountHalalas: amount.halalas!,
          balanceHalalas: widget.balanceHalalas,
        ),
      );
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => SendReviewScreen(
            controller: _intent,
            balanceHalalas: widget.balanceHalalas,
          ),
        ),
      );
      if (mounted) _afterReview();
    } on MoneyApiException catch (error) {
      if (!mounted) return;
      if (error.isAuthenticationRequired) {
        await services.session.expire();
        return;
      }
      setState(() {
        _busy = false;
        _show(error);
      });
    }
  }

  /// Back from review: a definite refusal is shown where it belongs, with
  /// every typed value still in the form.
  void _afterReview() {
    final refusal = _intent.refusal;
    if (_intent.state == SubmissionState.businessRefused && refusal != null) {
      setState(() => _show(refusal));
    } else {
      setState(() {});
    }
  }

  void _show(MoneyApiException error) {
    final text = Messages.forMoneyError(AppLocalizations.of(context), error);
    switch (_fieldFor(error)) {
      case _Field.email:
        _emailError = text;
      case _Field.amount:
        _amountError = text;
      case _Field.banner:
        _error = text;
    }
  }

  static _Field _fieldFor(MoneyApiException error) {
    final code = error.code;
    if (code == MoneyErrorCode.recipientNotFound ||
        code == MoneyErrorCode.selfTransfer) {
      return _Field.email;
    }
    if (code == MoneyErrorCode.amountOutOfRange ||
        code == MoneyErrorCode.insufficientFunds) {
      return _Field.amount;
    }
    return _Field.banner;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formats = Formats.of(context);
    final services = AppServices.of(context);
    return Scaffold(
      backgroundColor: RaadColors.background,
      appBar: AppBar(
        title: Text(l10n.sendTitle),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            _recipientSection(l10n, services),
            const SizedBox(height: 14),
            _amountSection(l10n, formats),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: StatusBanner(
                  kind: StatusKind.error,
                  text: _error!,
                  textKey: const ValueKey('send.error'),
                ),
              ),
            // Shown next to Continue after an uncertain transfer was dropped,
            // until the person has looked at their history.
            if (_intent.checkHistoryFirst)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: StatusBanner(
                  kind: StatusKind.warning,
                  text: l10n.checkHistoryFirst,
                  textKey: const ValueKey('send.checkHistoryFirst'),
                  action: TextButton(
                    key: const ValueKey('send.openHistory'),
                    onPressed: _openHistory,
                    child: Text(l10n.historyCheck),
                  ),
                ),
              ),
            const SendingNeedsConnection(textKey: ValueKey('send.offline')),
            ConnectionBuilder(
              builder: (context, online) => FilledButton(
                key: const ValueKey('send.continue'),
                onPressed: _busy || !online ? null : _continue,
                child: _busy
                    ? Semantics(
                        label: l10n.loading,
                        child: const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RaadColors.background,
                          ),
                        ),
                      )
                    : Text(l10n.sendContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipientSection(AppLocalizations l10n, AppServices services) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RaadColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RaadColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.sendRecipientSection.toUpperCase(),
              style: const TextStyle(
                color: RaadColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('send.email'),
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            // An address reads left to right, aligned to the start side.
            textDirection: TextDirection.ltr,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            decoration: InputDecoration(
              labelText: l10n.sendRecipientLabel,
              hintText: 'name@example.com',
              errorText: _emailError,
              errorMaxLines: 3,
              prefixIcon: const Icon(
                Icons.alternate_email_rounded,
                color: RaadColors.textSecondary,
                size: 20,
              ),
            ),
            onChanged: (_) => _clearErrors(),
          ),
          if (services.demoShortcuts) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('send.demoFill'),
              onPressed: () {
                _email.text = fakeOmar.email;
                _clearErrors();
              },
              icon: const Icon(
                Icons.bolt_rounded,
                size: 14,
                color: RaadColors.cyanAccent,
              ),
              label: Text(
                l10n.sendDemoFill(fakeOmar.email),
                style: const TextStyle(
                  color: RaadColors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The large amount field from the co-engineer's design, with the limits
  /// shown before entry and integer-only quick amounts.
  Widget _amountSection(AppLocalizations l10n, Formats formats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: RaadColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RaadColors.cyanGlow, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1400E5FF),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.sendAmountSection.toUpperCase(),
              style: const TextStyle(
                color: RaadColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('send.amount'),
            controller: _amount,
            enabled: !_busy,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: RaadColors.textPrimary,
              letterSpacing: -1.0,
            ),
            decoration: InputDecoration(
              labelText: l10n.sendAmountLabel,
              floatingLabelAlignment: FloatingLabelAlignment.center,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              hintText: '0.00',
              hintStyle: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: RaadColors.textMuted,
                letterSpacing: -1.0,
              ),
              suffixText: ' ${l10n.currencySar}',
              suffixStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: RaadColors.cyanAccent,
              ),
              helperText: l10n.sendAmountHint,
              helperMaxLines: 2,
              helperStyle: const TextStyle(color: RaadColors.textSecondary),
              errorText: _amountError,
              errorMaxLines: 3,
              errorStyle: const TextStyle(
                fontSize: 12,
                color: RaadColors.error,
              ),
            ),
            onChanged: (_) => _clearErrors(),
          ),
          const SizedBox(height: 10),
          // Available balance badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: RaadColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RaadColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 14,
                    color: RaadColors.cyanAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.sendAvailable(formats.money(widget.balanceHalalas)),
                    key: const ValueKey('send.available'),
                    style: const TextStyle(
                      color: RaadColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Quick amounts, all whole halalas; "Max" is the most one transfer
          // may send from this balance.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final halalas in const [5000, 10000, 25000, 50000])
                _quickAmountChip(
                  key: ValueKey('send.quick.$halalas'),
                  text: formatHalalas(halalas, withCurrency: false),
                  label: formats.money(halalas),
                  semantics: l10n.sendQuickAmount(formats.money(halalas)),
                ),
              _quickAmountChip(
                key: const ValueKey('send.max'),
                text: maxSendableText(widget.balanceHalalas),
                label: l10n.sendMax,
                semantics: l10n.sendMaxHint(
                  '${maxSendableText(widget.balanceHalalas)} '
                  '${l10n.currencySar}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAmountChip({
    required Key key,
    required String text,
    required String label,
    required String semantics,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        key: key,
        onTap: _busy ? null : () => _fillAmount(text),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: RaadColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: RaadColors.cardBorder),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: RaadColors.cyanAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

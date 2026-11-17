import 'package:flutter/material.dart';

import '../api/money_service.dart';
import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../money/halalas.dart';
import '../ui/messages.dart';
import '../ui/raad_theme.dart';
import 'send_review_screen.dart';

/// US3.1 and US3.4: recipient email and amount, then the recipient lookup.
///
/// The entered values stay in the form after any refusal (AC3.4.3).
class SendFormScreen extends StatefulWidget {
  const SendFormScreen({super.key, required this.balanceHalalas});

  final int balanceHalalas;

  @override
  State<SendFormScreen> createState() => _SendFormScreenState();
}

class _SendFormScreenState extends State<SendFormScreen> {
  final _email = TextEditingController();
  final _amount = TextEditingController();
  String? _emailError;
  String? _amountError;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_emailError == null && _amountError == null && _error == null) return;
    setState(() {
      _emailError = null;
      _amountError = null;
      _error = null;
    });
  }

  void _setPresetAmount(String value) {
    setState(() {
      _amount.text = value;
      _amountError = null;
      _error = null;
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    final email = normalizeEmail(_email.text);
    final amount = parseSarToHalalas(_amount.text);
    String? emailError;
    String? amountError;
    if (email.isEmpty) {
      emailError = "Enter the recipient's email address.";
    } else if (!looksLikeEmail(email)) {
      emailError = 'Enter a complete email address.';
    }
    if (_amount.text.trim().isEmpty) {
      amountError = 'Enter an amount.';
    } else if (amount == null) {
      amountError = 'Enter an amount in SAR with up to two decimals.';
    } else if (amount > widget.balanceHalalas) {
      amountError = Messages.insufficientFunds;
    }
    setState(() {
      _emailError = emailError;
      _amountError = amountError;
      _error = null;
    });
    if (emailError != null || amountError != null || amount == null) return;

    setState(() => _busy = true);
    final services = AppServices.of(context);
    final navigator = Navigator.of(context);
    try {
      final recipient = await services.money.resolveRecipient(email);
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await navigator.push<ReviewRefused>(
        MaterialPageRoute(
          builder: (_) => SendReviewScreen(
            recipient: recipient,
            recipientEmail: email,
            amountHalalas: amount,
            balanceHalalas: widget.balanceHalalas,
          ),
        ),
      );
      if (outcome != null && mounted) setState(() => _error = outcome.message);
    } on MoneyApiException catch (error) {
      if (!mounted) return;
      if (error.isAuthenticationRequired) {
        await showSignIn(context, notice: Messages.sessionExpired);
        return;
      }
      setState(() {
        _busy = false;
        _error = Messages.forMoneyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RaadColors.background,
      appBar: AppBar(
        title: const Text('Send money'),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Recipient Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RaadColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: RaadColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECIPIENT',
                    style: TextStyle(
                      color: RaadColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('send.email'),
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: "Recipient's email",
                      hintText: 'name@raad.test',
                      errorText: _emailError,
                      prefixIcon: const Icon(
                        Icons.alternate_email_rounded,
                        color: RaadColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    onChanged: (_) => _clearErrors(),
                  ),
                  const SizedBox(height: 8),
                  // Demo shortcut for instant testing
                  InkWell(
                    onTap: () {
                      setState(() {
                        _email.text = 'omar@raad.test';
                        _clearErrors();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: RaadColors.cyanAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Quick Send: Omar (omar@raad.test)',
                            style: TextStyle(
                              color: RaadColors.cyanAccent.withValues(
                                alpha: 0.9,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Large Hero Amount Section (Barq style: huge numbers, centered, clean)
            Container(
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
                  const Text(
                    'TRANSFER AMOUNT',
                    style: TextStyle(
                      color: RaadColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Large Number Amount TextField
                  TextField(
                    key: const ValueKey('send.amount'),
                    controller: _amount,
                    enabled: !_busy,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: RaadColors.textPrimary,
                      letterSpacing: -1.0,
                    ),
                    decoration: InputDecoration(
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
                      suffixText: ' SAR',
                      suffixStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: RaadColors.cyanAccent,
                      ),
                      errorText: _amountError,
                      errorStyle: const TextStyle(
                        fontSize: 12,
                        color: RaadColors.error,
                      ),
                    ),
                    onChanged: (_) => _clearErrors(),
                  ),
                  const SizedBox(height: 10),

                  // Available Balance Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: RaadColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: RaadColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 14,
                          color: RaadColors.cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Available: ${formatHalalas(widget.balanceHalalas)}',
                          key: const ValueKey('send.available'),
                          style: const TextStyle(
                            color: RaadColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Amount Preset Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _quickAmountChip('50'),
                        const SizedBox(width: 8),
                        _quickAmountChip('100'),
                        const SizedBox(width: 8),
                        _quickAmountChip('250'),
                        const SizedBox(width: 8),
                        _quickAmountChip('500'),
                        const SizedBox(width: 8),
                        _quickAmountChip(
                          (widget.balanceHalalas / 100).toStringAsFixed(2),
                          label: 'Max',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error banner (if API returns error)
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: RaadColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: RaadColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: RaadColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        key: const ValueKey('send.error'),
                        style: const TextStyle(
                          color: RaadColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Continue Button
            FilledButton(
              key: const ValueKey('send.continue'),
              onPressed: _busy ? null : _continue,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RaadColors.background,
                      ),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAmountChip(String value, {String? label}) {
    final displayText = label ?? '$value SAR';
    return InkWell(
      onTap: () => _setPresetAmount(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: RaadColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: RaadColors.cardBorder),
        ),
        child: Text(
          displayText,
          style: const TextStyle(
            color: RaadColors.cyanAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

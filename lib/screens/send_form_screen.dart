import 'package:flutter/material.dart';

import '../api/money_service.dart';
import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../auth/auth_service.dart';
import '../money/halalas.dart';
import '../ui/messages.dart';
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
      appBar: AppBar(
        title: const Text('Send money'),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Available: ${formatHalalas(widget.balanceHalalas)}',
              key: const ValueKey('send.available'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('send.email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: "Recipient's email",
                errorText: _emailError,
              ),
              onChanged: (_) => _clearErrors(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('send.amount'),
              controller: _amount,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: 'SAR',
                errorText: _amountError,
              ),
              onChanged: (_) => _clearErrors(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('send.error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('send.continue'),
              onPressed: _busy ? null : _continue,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

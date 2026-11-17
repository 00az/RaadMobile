import 'package:flutter/material.dart';

import '../api/generated/money_api_client.dart';
import '../app/raad_app.dart';
import '../money/halalas.dart';
import '../ui/raad_theme.dart';

/// US3.1 AC3.1.2: the completed transfer, with its human reference shown
/// apart from the transfer ID.
class SendResultScreen extends StatelessWidget {
  const SendResultScreen({super.key, required this.result});

  final TransferResult result;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transfer sent'),
          automaticallyImplyLeading: false,
          actions: const [EnvironmentChip()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RaadColors.success.withValues(alpha: 0.12),
                    border: Border.all(
                      color: RaadColors.success.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: RaadColors.success.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: RaadColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You sent ${formatHalalas(result.amount.amountHalalas)} '
                'to ${result.recipient.displayName}.',
                key: const ValueKey('result.summary'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RaadColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RaadColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: RaadColors.cardBorder),
                ),
                child: Column(
                  children: [
                    _row('Reference', result.reference, 'result.reference'),
                    const Divider(color: RaadColors.cardBorder, height: 24),
                    _row(
                      'New balance',
                      formatHalalas(result.balanceAfter.amountHalalas),
                      'result.balance',
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                key: const ValueKey('result.done'),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    String key, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: RaadColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            key: ValueKey(key),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isHighlight
                  ? RaadColors.cyanAccent
                  : RaadColors.textPrimary,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              fontSize: isHighlight ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }
}

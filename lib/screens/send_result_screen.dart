import 'package:flutter/material.dart';

import '../api/generated/money_api_client.dart';
import '../app/raad_app.dart';
import '../money/halalas.dart';

/// US3.1 AC3.1.2: the completed transfer, with its human reference shown
/// apart from the transfer ID.
class SendResultScreen extends StatelessWidget {
  const SendResultScreen({super.key, required this.result});

  final TransferResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.check_circle,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'You sent ${formatHalalas(result.amount.amountHalalas)} '
                'to ${result.recipient.displayName}.',
                key: const ValueKey('result.summary'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              _row('Reference', result.reference, 'result.reference'),
              _row(
                'New balance',
                formatHalalas(result.balanceAfter.amountHalalas),
                'result.balance',
              ),
              const SizedBox(height: 24),
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

  Widget _row(String label, String value, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(child: Text(value, key: ValueKey(key))),
        ],
      ),
    );
  }
}

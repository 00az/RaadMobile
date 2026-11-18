import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/raad_app.dart';
import '../l10n/app_localizations.dart';
import '../ui/raad_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/status_banner.dart';

/// S11 (US1.4, US5.1): the language and sign-out.
///
/// Sign out ends the session at once; the app shell then clears every
/// private screen so neither Back nor reopening shows wallet data (AC1.4.2).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle),
        actions: const [EnvironmentChip()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            const OfflineBanner(),
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  l10n.accountLanguage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const LanguageSelector(),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const ValueKey('account.signOut'),
              onPressed: () => AppServices.of(context).session.signOut(),
              icon: const Icon(Icons.logout_rounded, color: RaadColors.error),
              label: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

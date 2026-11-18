/// Choosing Arabic or English (US5.1, AC5.1.3). The change applies at once,
/// on the same screen, without signing in again; it never touches a draft,
/// a transfer's key or a request in flight.
library;

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/language.dart';
import '../l10n/app_localizations.dart';

AppLanguage currentLanguage(BuildContext context) =>
    AppLocalizations.of(context).localeName == 'ar'
    ? AppLanguage.ar
    : AppLanguage.en;

/// A top-bar button naming the other language, in that language.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final other = currentLanguage(context) == AppLanguage.ar
        ? AppLanguage.en
        : AppLanguage.ar;
    final label = other == AppLanguage.ar
        ? l10n.languageArabic
        : l10n.languageEnglish;
    return Semantics(
      label: '${l10n.accountLanguage}: $label',
      button: true,
      excludeSemantics: true,
      child: TextButton(
        key: const ValueKey('app.language'),
        onPressed: () => AppServices.of(context).language.choose(other),
        child: Text(label),
      ),
    );
  }
}

/// The radio choice on the account screen.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RadioGroup<AppLanguage>(
      groupValue: currentLanguage(context),
      onChanged: (language) {
        if (language != null) AppServices.of(context).language.choose(language);
      },
      child: Column(
        children: [
          RadioListTile<AppLanguage>(
            key: const ValueKey('language.ar'),
            value: AppLanguage.ar,
            title: Text(l10n.languageArabic),
          ),
          RadioListTile<AppLanguage>(
            key: const ValueKey('language.en'),
            value: AppLanguage.en,
            title: Text(l10n.languageEnglish),
          ),
        ],
      ),
    );
  }
}

/// The app's language: Arabic or English, chosen once per installation
/// (US5.1, FR6.1).
///
/// Until the person chooses, the app follows the phone's language when it is
/// Arabic or English, and uses English otherwise. Changing it changes text
/// and direction at once; it never touches the session, a draft or a
/// transfer's key.
library;

import 'package:flutter/widgets.dart';

import 'protected_store.dart';

enum AppLanguage { ar, en }

final class LanguageSetting extends ChangeNotifier {
  LanguageSetting(this._store);

  /// Not tied to an account: signing out keeps it.
  static const String storageKey = 'raad.install.language';

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ar')];

  final ProtectedStore _store;
  AppLanguage? _chosen;

  /// The person's choice, or null while the app follows the phone.
  AppLanguage? get chosen => _chosen;

  /// The locale to force, or null to follow the phone.
  Locale? get locale => _chosen == null ? null : Locale(_chosen!.name);

  /// Reads the stored choice once at start.
  Future<void> load() async {
    try {
      final stored = AppLanguage.values
          .asNameMap()[await _store.read(storageKey)];
      if (stored != null && stored != _chosen) {
        _chosen = stored;
        notifyListeners();
      }
    } on Object {
      // Unreadable storage: keep following the phone.
    }
  }

  Future<void> choose(AppLanguage language) async {
    if (_chosen != language) {
      _chosen = language;
      notifyListeners();
    }
    try {
      await _store.write(storageKey, language.name);
    } on Object {
      // The choice still applies now; it is only not remembered.
    }
  }

  /// Arabic when the phone's language is Arabic, otherwise English.
  static Locale resolve(List<Locale>? phoneLocales) =>
      phoneLocales?.firstOrNull?.languageCode == 'ar'
      ? const Locale('ar')
      : const Locale('en');
}

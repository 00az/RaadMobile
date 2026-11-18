// Fails when the Arabic and English catalogs do not match (US5.1, BR3.7):
// a key missing from either language, an empty value, or a placeholder one
// language uses and the other does not.
//
//   dart run tool/check_l10n.dart [lib/l10n/app_en.arb lib/l10n/app_ar.arb]

import 'dart:convert';
import 'dart:io';

/// Every problem between the [english] template and the [arabic] catalog.
List<String> catalogProblems(
  Map<String, Object?> english,
  Map<String, Object?> arabic,
) {
  bool isMessage(String key) => !key.startsWith('@');
  final problems = <String>[];
  final englishKeys = english.keys.where(isMessage).toSet();
  final arabicKeys = arabic.keys.where(isMessage).toSet();

  for (final key in englishKeys.difference(arabicKeys)) {
    problems.add('"$key" is missing in Arabic.');
  }
  for (final key in arabicKeys.difference(englishKeys)) {
    problems.add('"$key" is in Arabic only.');
  }
  for (final (language, catalog) in [
    ('English', english),
    ('Arabic', arabic),
  ]) {
    for (final key in catalog.keys.where(isMessage)) {
      final value = catalog[key];
      if (value is! String || value.trim().isEmpty) {
        problems.add('"$key" is empty in $language.');
      }
    }
  }
  for (final key in englishKeys.intersection(arabicKeys)) {
    final en = _placeholders(english[key]);
    final ar = _placeholders(arabic[key]);
    if (en.length != ar.length || !en.containsAll(ar)) {
      problems.add(
        '"$key" uses {${en.join(', ')}} in English but '
        '{${ar.join(', ')}} in Arabic.',
      );
    }
  }
  for (final key in english.keys.where(
    (k) => k.startsWith('@') && k != '@@locale',
  )) {
    if (!englishKeys.contains(key.substring(1))) {
      problems.add('"$key" describes a message that does not exist.');
    }
  }
  problems.sort();
  return problems;
}

Set<String> _placeholders(Object? value) => value is String
    ? RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m.group(1)!).toSet()
    : const {};

Map<String, Object?> readCatalog(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main(List<String> args) {
  final english = args.isNotEmpty ? args[0] : 'lib/l10n/app_en.arb';
  final arabic = args.length > 1 ? args[1] : 'lib/l10n/app_ar.arb';
  final problems = catalogProblems(readCatalog(english), readCatalog(arabic));
  final keys = readCatalog(english).keys.where((k) => !k.startsWith('@'));
  if (problems.isEmpty) {
    stdout.writeln(
      'Arabic and English catalogs match: ${keys.length} messages.',
    );
    return;
  }
  stderr
    ..writeln('The catalogs do not match:')
    ..writeln(problems.map((p) => '  - $p').join('\n'));
  exit(1);
}

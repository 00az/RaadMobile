// The Arabic and English catalogs (US5.1, BR3.7, NFR9.11): every key in both,
// none empty, the same placeholders, Western digits, and a safe message for
// every outcome code in both languages.

import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/api/money_service.dart';
import 'package:raad_mobile/auth/auth_service.dart';
import 'package:raad_mobile/ui/messages.dart';

import '../tool/check_l10n.dart';
import 'support/harness.dart';

void main() {
  final english = readCatalog('lib/l10n/app_en.arb');
  final arabic = readCatalog('lib/l10n/app_ar.arb');

  test('every message is in both languages, with no empty value', () {
    expect(catalogProblems(english, arabic), isEmpty);
  });

  test('the check finds a missing key, an empty value and a lost '
      'placeholder', () {
    final problems = catalogProblems(
      {'a': 'A', 'b': 'B {x}', 'c': 'C', '@b': <String, Object?>{}},
      {'a': ' ', 'b': 'ب'},
    );
    expect(problems, hasLength(3));
    expect(problems.join('\n'), contains('"c" is missing in Arabic'));
    expect(problems.join('\n'), contains('"a" is empty in Arabic'));
    expect(problems.join('\n'), contains('"b" uses {x}'));
  });

  test('no Arabic text is a copy of the English', () {
    final copied = [
      for (final key in english.keys)
        if (!key.startsWith('@') && english[key] == arabic[key]) key,
    ];
    // The language names are written in their own language in both.
    expect(copied, unorderedEquals(['languageArabic', 'languageEnglish']));
  });

  test('Arabic text uses Western digits (A8)', () {
    final easternDigits = RegExp('[٠-٩۰-۹]');
    for (final entry in arabic.entries) {
      if (entry.value is String) {
        expect(
          easternDigits.hasMatch(entry.value! as String),
          isFalse,
          reason: entry.key,
        );
      }
    }
    expect(ar.currencySar, 'ر.س');
    expect(en.currencySar, 'SAR');
  });

  test('every sign-in outcome has its own text in both languages', () {
    for (final l10n in [en, ar]) {
      for (final code in AuthFailureCode.values) {
        expect(Messages.forAuthFailure(l10n, code), isNotEmpty);
      }
      expect(
        Messages.forAuthFailure(l10n, AuthFailureCode.signInFailed),
        isNot(Messages.forAuthFailure(l10n, AuthFailureCode.rateLimited)),
      );
    }
  });

  test('every Money API code, and an unknown one, has a safe text in both '
      'languages', () {
    for (final l10n in [en, ar]) {
      final texts = {
        for (final code in [
          'RECIPIENT_NOT_FOUND',
          'SELF_TRANSFER',
          'AMOUNT_OUT_OF_RANGE',
          'INSUFFICIENT_FUNDS',
          'VALIDATION_ERROR',
          'RATE_LIMITED',
          'FORBIDDEN',
          'IDEMPOTENCY_KEY_REUSED',
          'AUTHENTICATION_REQUIRED',
          MoneyErrorCode.network,
          'A_CODE_FROM_A_LATER_VERSION',
        ])
          code: Messages.forMoneyError(l10n, MoneyApiException(code: code)),
      };
      expect(texts.values.every((t) => t.isNotEmpty), isTrue);
      expect(texts['A_CODE_FROM_A_LATER_VERSION'], l10n.genericError);
      expect(
        Messages.rateLimited(l10n, const Duration(seconds: 30)),
        l10n.tooManyAttemptsSeconds(30),
      );
    }
  });
}

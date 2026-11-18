/// How amounts, times and technical values are written on screen in either
/// language (A8 proposed; mockups "Mixed-direction rules").
///
/// - Digits are always Western (0 to 9), in Arabic as well.
/// - An amount is the figure, then `SAR` or `ر.س`, kept together as one
///   left-to-right unit.
/// - Emails, references and codes keep left-to-right order inside Arabic
///   text, isolated so the surrounding words do not reorder them.
/// - Times are the phone's local time of the UTC instant.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../l10n/app_localizations.dart';
import '../money/halalas.dart';

final class Formats {
  Formats._(this._l10n, this._rtl) {
    _useWesternDigits();
  }

  factory Formats.of(BuildContext context) => Formats._(
    AppLocalizations.of(context),
    Directionality.of(context) == TextDirection.rtl,
  );

  /// For code that has the localizations but no widget context.
  factory Formats.forLocalizations(AppLocalizations l10n) =>
      Formats._(l10n, l10n.localeName == 'ar');

  final AppLocalizations _l10n;
  final bool _rtl;

  /// LEFT-TO-RIGHT ISOLATE (U+2066) and POP DIRECTIONAL ISOLATE (U+2069),
  /// built from their code points so the source shows no invisible marks.
  static final String _isolateLtr = String.fromCharCode(0x2066);
  static final String _popIsolate = String.fromCharCode(0x2069);

  static bool _digitsChosen = false;

  /// Arabic dates in intl default to Arabic-Indic digits; A8 asks for
  /// Western digits in both languages.
  static void _useWesternDigits() {
    if (_digitsChosen) return;
    DateFormat.useNativeDigitsByDefaultFor('ar', false);
    _digitsChosen = true;
  }

  /// [value] as one left-to-right unit. In English it is returned as it is.
  String ltr(String value) => _rtl ? '$_isolateLtr$value$_popIsolate' : value;

  /// Whole halalas as SAR, for example `1,234.56 SAR` or `1,234.56 ر.س`.
  String money(int halalas, {bool signed = false}) =>
      ltr(formatHalalas(halalas, signed: signed, currency: _l10n.currencySar));

  /// Day, month name, year and time in the phone's time zone, for example
  /// `11 Nov 2026, 14:05`.
  String dateTime(DateTime instant) =>
      dateTimeAt(instant, instant.toLocal().timeZoneOffset);

  /// The same instant at a fixed [offset] from UTC; the time zone changes
  /// only how it is written, never the instant or the order of rows.
  String dateTimeAt(DateTime instant, Duration offset) => DateFormat(
    'd MMM yyyy, HH:mm',
    _l10n.localeName,
  ).format(instant.toUtc().add(offset));

  /// The time of day, or the date and time when it was not today.
  String updatedAt(DateTime instant, DateTime now) {
    final local = instant.toLocal();
    final today = now.toLocal();
    final sameDay =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    return sameDay
        ? DateFormat('HH:mm', _l10n.localeName).format(local)
        : dateTime(instant);
  }
}

/// Removes the direction marks [Formats.ltr] adds, for tests and for text
/// that is compared rather than shown.
String withoutDirectionMarks(String text) => String.fromCharCodes(
  text.runes.where((unit) => unit < 0x2066 || unit > 0x2069),
);

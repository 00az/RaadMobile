/// Money in RAAD is always a whole number of halalas (1 SAR = 100 halalas).
///
/// Nothing in this file uses floating point. Text is parsed digit by digit
/// into an integer, and integers are formatted with integer division.
library;

/// Plain digits ("1250") or comma-grouped digits ("1,250"), then an optional
/// fraction of one or two digits.
final RegExp _sarText = RegExp(r'^(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?$');

/// Like [_sarText], but takes a fraction of any length, so that a third
/// decimal can be named as too precise rather than as not a number.
final RegExp _sarTextAnyFraction = RegExp(
  r'^(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d+))?$',
);

/// The most halalas a parsed amount may hold, which keeps the arithmetic far
/// from integer overflow. It is not a business limit: the Money API applies
/// the transfer range.
const int maxParsableHalalas = 100000000000000; // 1,000,000,000,000.00 SAR

/// The smallest and largest single transfer: 1.00 and 500.00 SAR, inclusive,
/// with no daily total (BR3.3). The Money API stays authoritative; the app
/// checks early so the person sees the reason before any request.
const int minTransferHalalas = 100;
const int maxTransferHalalas = 50000;

/// Typed amounts longer than this are refused before parsing.
const int maxAmountInputLength = 20;

/// Parses SAR text such as `100`, `100.5`, `0.75` or `1,250.75` into whole
/// halalas.
///
/// Returns null when the text is not a positive amount with at most two
/// decimal places, for example `0`, `-5`, `1.234`, `1e3` or `abc`.
int? parseSarToHalalas(String input) {
  final match = _sarText.firstMatch(input.trim());
  if (match == null) return null;
  final wholeDigits = match.group(1)!.replaceAll(',', '');
  final fractionDigits = (match.group(2) ?? '').padRight(2, '0');
  if (wholeDigits.length > 13) return null;
  final halalas = _digits(wholeDigits) * 100 + _digits(fractionDigits);
  if (halalas <= 0 || halalas > maxParsableHalalas) return null;
  return halalas;
}

/// Why a typed transfer amount cannot be sent.
enum AmountProblem {
  /// Nothing was typed.
  empty,

  /// The text is not an amount in SAR at all.
  notANumber,

  /// Zero, negative, below 1.00 or above 500.00 SAR, more than two decimals
  /// (a fraction of a halala) or absurdly long: the message names the limits.
  outOfRange,

  /// Within the limits but more than the balance the app last saw.
  insufficientBalance,
}

/// The result of checking a typed amount: [halalas] when it may be sent,
/// otherwise the [problem].
final class AmountCheck {
  const AmountCheck.ok(int this.halalas) : problem = null;
  const AmountCheck.refused(AmountProblem this.problem) : halalas = null;

  final int? halalas;
  final AmountProblem? problem;

  bool get isValid => problem == null;
}

/// Checks a typed SAR amount for one transfer from [balanceHalalas].
///
/// Arabic-Indic digits and the Arabic decimal and thousands marks are read
/// as their Western equivalents, one character at a time, so a person on an
/// Arabic keyboard can type an amount; the app still shows Western digits.
AmountCheck checkTransferAmount(String input, {required int balanceHalalas}) {
  final text = westernDigits(input).trim();
  if (text.isEmpty) return const AmountCheck.refused(AmountProblem.empty);
  if (text.length > maxAmountInputLength) {
    return const AmountCheck.refused(AmountProblem.outOfRange);
  }
  final negative = text.startsWith('-');
  final match = _sarTextAnyFraction.firstMatch(
    negative ? text.substring(1) : text,
  );
  if (match == null) {
    return const AmountCheck.refused(AmountProblem.notANumber);
  }
  final wholeDigits = match.group(1)!.replaceAll(',', '');
  final fraction = match.group(2) ?? '';
  if (negative || fraction.length > 2 || wholeDigits.length > 13) {
    return const AmountCheck.refused(AmountProblem.outOfRange);
  }
  final halalas =
      _digits(wholeDigits) * 100 + _digits(fraction.padRight(2, '0'));
  if (halalas < minTransferHalalas || halalas > maxTransferHalalas) {
    return const AmountCheck.refused(AmountProblem.outOfRange);
  }
  if (halalas > balanceHalalas) {
    return const AmountCheck.refused(AmountProblem.insufficientBalance);
  }
  return AmountCheck.ok(halalas);
}

/// The most one transfer may send from [balanceHalalas]: the whole balance,
/// up to the 500.00 SAR limit, as SAR text the amount field accepts.
String maxSendableText(int balanceHalalas) {
  final most = balanceHalalas < maxTransferHalalas
      ? balanceHalalas
      : maxTransferHalalas;
  return formatHalalas(most < 0 ? 0 : most, withCurrency: false);
}

/// Replaces Arabic-Indic (U+0660 to U+0669) and Extended Arabic-Indic
/// (U+06F0 to U+06F9) digits with 0 to 9, the Arabic decimal mark with `.`
/// and the Arabic thousands mark with `,`. Other characters are kept.
String westernDigits(String input) {
  final out = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else if (unit == 0x066B) {
      out.write('.');
    } else if (unit == 0x066C) {
      out.write(',');
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// Formats halalas as SAR with comma grouping and exactly two decimals, for
/// example `123456` as `1,234.56 SAR`. Digits are always Western (A8);
/// [currency] is `SAR` in English and `ر.س` in Arabic.
///
/// [signed] adds a leading `+` to positive amounts; negative amounts always
/// carry a leading `-`.
String formatHalalas(
  int halalas, {
  bool withCurrency = true,
  bool signed = false,
  String currency = 'SAR',
}) {
  final negative = halalas < 0;
  final magnitude = halalas.abs();
  final whole = _groupThousands((magnitude ~/ 100).toString());
  final fraction = (magnitude % 100).toString().padLeft(2, '0');
  final sign = negative ? '-' : (signed && magnitude > 0 ? '+' : '');
  final number = '$sign$whole.$fraction';
  return withCurrency ? '$number $currency' : number;
}

/// Reads a string of ASCII digits into an integer, one digit at a time.
int _digits(String digits) {
  var value = 0;
  for (final unit in digits.codeUnits) {
    value = value * 10 + (unit - 0x30);
  }
  return value;
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

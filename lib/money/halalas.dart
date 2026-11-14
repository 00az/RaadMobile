/// Money in RAAD is always a whole number of halalas (1 SAR = 100 halalas).
///
/// Nothing in this file uses floating point. Text is parsed digit by digit
/// into an integer, and integers are formatted with integer division.
library;

/// Plain digits ("1250") or comma-grouped digits ("1,250"), then an optional
/// fraction of one or two digits.
final RegExp _sarText = RegExp(r'^(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?$');

/// The most halalas a parsed amount may hold, which keeps the arithmetic far
/// from integer overflow. It is not a business limit: the Money API applies
/// the transfer range.
const int maxParsableHalalas = 100000000000000; // 1,000,000,000,000.00 SAR

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
  final halalas = int.parse(wholeDigits) * 100 + int.parse(fractionDigits);
  if (halalas <= 0 || halalas > maxParsableHalalas) return null;
  return halalas;
}

/// Formats halalas as SAR with comma grouping and exactly two decimals, for
/// example `123456` as `1,234.56 SAR`.
///
/// [signed] adds a leading `+` to positive amounts; negative amounts always
/// carry a leading `-`.
String formatHalalas(
  int halalas, {
  bool withCurrency = true,
  bool signed = false,
}) {
  final negative = halalas < 0;
  final magnitude = halalas.abs();
  final whole = _groupThousands((magnitude ~/ 100).toString());
  final fraction = (magnitude % 100).toString().padLeft(2, '0');
  final sign = negative ? '-' : (signed && magnitude > 0 ? '+' : '');
  final number = '$sign$whole.$fraction';
  return withCurrency ? '$number SAR' : number;
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

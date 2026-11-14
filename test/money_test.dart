import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/money/halalas.dart';

void main() {
  group('parseSarToHalalas', () {
    const valid = {
      '100': 10000,
      '100.5': 10050,
      '100.50': 10050,
      '0.01': 1,
      '0.75': 75,
      '1,250.75': 125075,
      '12,345,678': 1234567800,
      '  42  ': 4200,
      '500.00': 50000,
    };
    valid.forEach((text, halalas) {
      test('reads "$text" as $halalas halalas', () {
        expect(parseSarToHalalas(text), halalas);
      });
    });

    const invalid = [
      '',
      '0',
      '0.00',
      '-5',
      '1.234',
      '1e3',
      'abc',
      '1,25.00',
      '1.',
      '.5',
      '10 SAR',
      '١٠٠',
      '99999999999999',
    ];
    for (final text in invalid) {
      test('refuses "$text"', () {
        expect(parseSarToHalalas(text), isNull);
      });
    }
  });

  group('formatHalalas', () {
    test('formats with grouping, two decimals and the currency', () {
      expect(formatHalalas(123456), '1,234.56 SAR');
      expect(formatHalalas(100000), '1,000.00 SAR');
      expect(formatHalalas(5), '0.05 SAR');
      expect(formatHalalas(0), '0.00 SAR');
      expect(formatHalalas(123456789012), '1,234,567,890.12 SAR');
    });

    test('marks direction when asked', () {
      expect(formatHalalas(-10000), '-100.00 SAR');
      expect(formatHalalas(25000, signed: true), '+250.00 SAR');
      expect(formatHalalas(0, signed: true), '0.00 SAR');
      expect(formatHalalas(1050, withCurrency: false), '10.50');
    });

    test('round-trips every parsed amount exactly', () {
      for (final halalas in [1, 99, 100, 101, 10050, 99999, 123456789]) {
        final text = formatHalalas(halalas, withCurrency: false);
        expect(parseSarToHalalas(text), halalas);
      }
    });
  });
}

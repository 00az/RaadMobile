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

    test('labels Arabic amounts ر.س with Western digits (A8)', () {
      expect(formatHalalas(123456, currency: 'ر.س'), '1,234.56 ر.س');
      expect(formatHalalas(-5000, currency: 'ر.س'), '-50.00 ر.س');
    });
  });

  group('checkTransferAmount (US3.3, US3.4, BR3.3)', () {
    AmountCheck check(String text, {int balance = 100000}) =>
        checkTransferAmount(text, balanceHalalas: balance);

    test('accepts 100 and 50000 halalas, the inclusive limits', () {
      expect(check('1').halalas, 100);
      expect(check('1.00').halalas, 100);
      expect(check('500').halalas, 50000);
      expect(check('500.00').halalas, 50000);
      expect(check('250.5').halalas, 25050);
    });

    test(
      'refuses 99 and 50001 halalas, zero and negatives with the limits',
      () {
        for (final text in ['0.99', '500.01', '0', '0.00', '-5', '-0.01']) {
          expect(check(text).problem, AmountProblem.outOfRange, reason: text);
        }
      },
    );

    test('refuses a fraction of a halala and very long input', () {
      expect(check('1.234').problem, AmountProblem.outOfRange);
      expect(check('1.005').problem, AmountProblem.outOfRange);
      expect(check('1' * 21).problem, AmountProblem.outOfRange);
      expect(check('99999999999999').problem, AmountProblem.outOfRange);
    });

    test('names empty and non-numeric text separately', () {
      expect(check('').problem, AmountProblem.empty);
      expect(check('   ').problem, AmountProblem.empty);
      for (final text in ['abc', '1e3', '1.', '.5', '10 SAR', '1,25.00']) {
        expect(check(text).problem, AmountProblem.notANumber, reason: text);
      }
    });

    test('sends the exact balance and refuses one halala more', () {
      expect(check('300.00', balance: 30000).halalas, 30000);
      expect(
        check('300.01', balance: 30000).problem,
        AmountProblem.insufficientBalance,
      );
    });

    test('names the limits before the balance, as the service does', () {
      expect(check('600', balance: 100).problem, AmountProblem.outOfRange);
    });

    test('reads Arabic-Indic digits and marks one digit at a time', () {
      expect(check('١٠٠').halalas, 10000);
      expect(check('١٢٫٥٠').halalas, 1250);
      expect(check('۱۰').halalas, 1000);
      expect(check('١٬٠٠٠', balance: 200000).problem, AmountProblem.outOfRange);
      expect(westernDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(westernDigits('abc'), 'abc');
    });
  });

  group('maxSendableText ("Max")', () {
    test('is the balance up to the 500.00 SAR limit, from integers', () {
      expect(maxSendableText(100000), '500.00');
      expect(maxSendableText(50000), '500.00');
      expect(maxSendableText(12345), '123.45');
      expect(maxSendableText(5), '0.05');
      expect(maxSendableText(0), '0.00');
    });

    test('always gives text the amount check reads back exactly', () {
      for (final balance in [100, 101, 9999, 12345, 49999, 50000, 100000]) {
        final text = maxSendableText(balance);
        expect(
          checkTransferAmount(text, balanceHalalas: balance).halalas,
          balance < maxTransferHalalas ? balance : maxTransferHalalas,
          reason: '$balance',
        );
      }
    });
  });
}

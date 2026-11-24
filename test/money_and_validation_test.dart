import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/core/utils/money.dart';
import 'package:moneywise/core/utils/validators.dart';

void main() {
  group('currency amounts', () {
    test('parses and formats values without losing precision', () {
      expect(parseMinorUnits('100,000.50', 'USD'), 10000050);
      expect(formatMinorUnits(10000050, 'USD'), 'USD 100,000.50');
      expect(parseMinorUnits('20,000', 'UGX'), 20000);
      expect(formatMinorUnits(20000, 'UGX'), 'UGX 20,000');
    });

    test('allows only zero-valued extra decimal places', () {
      expect(parseMinorUnits('1.230', 'USD'), 123);
      expect(() => parseMinorUnits('1.001', 'USD'), throwsFormatException);
      expect(() => parseMinorUnits('20.5', 'UGX'), throwsFormatException);
    });

    test('supports large exact amounts within SQLite integer storage', () {
      expect(parseMinorUnits('90071992547409.93', 'USD'), 9007199254740993);
      for (final value in ['abc', '-1', '0', '1.2.3']) {
        expect(
          () => parseMinorUnits(value, 'USD'),
          throwsFormatException,
          reason: 'Rejected $value',
        );
      }
      expect(
        () => parseMinorUnits('92233720368547758.08', 'USD'),
        throwsFormatException,
      );
      expect(parseMinorUnits('0', 'USD', allowZero: true), 0);
    });
  });

  group('form validation', () {
    test('requires a value and validates email format', () {
      expect(
        Validators.required('  ', 'Description'),
        'Description is required.',
      );
      expect(Validators.email('not-an-email'), 'Enter a valid email address.');
      expect(Validators.email('person@example.com'), isNull);
    });

    test('requires a sufficiently strong password', () {
      expect(Validators.password('short'), 'Use at least 8 characters.');
      expect(Validators.password('allletters'), 'Include letters and numbers.');
      expect(Validators.password('Moneywise123'), isNull);
    });
  });
}

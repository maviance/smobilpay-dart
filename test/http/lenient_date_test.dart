import 'package:smobilpay/src/http/lenient_date.dart';
import 'package:test/test.dart';

void main() {
  group('LenientDate.parse', () {
    test('parses ISO date (no time) as UTC midnight', () {
      expect(LenientDate.parse('2026-01-31'), DateTime.utc(2026, 1, 31));
    });

    test('parses instant (Z suffix)', () {
      expect(LenientDate.parse('2026-01-31T12:00:00Z'),
          DateTime.utc(2026, 1, 31, 12));
    });

    test('parses offset datetime', () {
      expect(LenientDate.parse('2026-01-31T12:00:00+01:00'),
          DateTime.utc(2026, 1, 31, 11));
    });

    test('parses local datetime (no offset) as UTC', () {
      expect(LenientDate.parse('2026-01-31T12:00:00'),
          DateTime.utc(2026, 1, 31, 12));
    });

    test('parses fractional seconds', () {
      expect(LenientDate.parse('2026-01-31T12:00:00.123Z'),
          DateTime.utc(2026, 1, 31, 12, 0, 0, 123));
    });

    test('throws FormatException on garbage', () {
      expect(() => LenientDate.parse('not-a-date'), throwsFormatException);
    });
  });

  group('LenientDate.parseOrNull', () {
    test('returns null for null',
        () => expect(LenientDate.parseOrNull(null), isNull));
    test('returns null for empty',
        () => expect(LenientDate.parseOrNull(''), isNull));
    test(
        'parses valid input',
        () => expect(
            LenientDate.parseOrNull('2026-01-31'), DateTime.utc(2026, 1, 31)));
  });

  group('LenientDate.formatInstant', () {
    test('formats UTC as ISO Z', () {
      expect(LenientDate.formatInstant(DateTime.utc(2026, 1, 31, 12)),
          '2026-01-31T12:00:00.000Z');
    });

    test('converts local to UTC before formatting', () {
      final local = DateTime.utc(2026, 1, 31, 12).toLocal();
      expect(LenientDate.formatInstant(local), endsWith('Z'));
    });
  });
}

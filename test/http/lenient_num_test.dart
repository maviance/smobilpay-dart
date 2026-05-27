import 'package:smobilpay/src/http/lenient_num.dart';
import 'package:test/test.dart';

void main() {
  group('LenientNum.asInt', () {
    test('int from int', () => expect(LenientNum.asInt(42), 42));
    test('int from string', () => expect(LenientNum.asInt('20053'), 20053));
    test('int from double', () => expect(LenientNum.asInt(3.9), 3));
    test('required null throws FormatException', () {
      expect(() => LenientNum.asInt(null), throwsA(isA<FormatException>()));
    });
    test('empty string throws FormatException', () {
      expect(() => LenientNum.asInt(''), throwsA(isA<FormatException>()));
    });
    test('garbage string throws FormatException', () {
      expect(() => LenientNum.asInt('abc'), throwsA(isA<FormatException>()));
    });
  });

  group('LenientNum.asIntOrNull', () {
    test('int from int', () => expect(LenientNum.asIntOrNull(7), 7));
    test('int from string', () => expect(LenientNum.asIntOrNull('100'), 100));
    test('null returns null', () => expect(LenientNum.asIntOrNull(null), null));
    test('empty string returns null',
        () => expect(LenientNum.asIntOrNull(''), null));
    test('garbage string throws FormatException', () {
      expect(() => LenientNum.asIntOrNull('not-a-number'),
          throwsA(isA<FormatException>()));
    });
  });

  group('LenientNum.asDouble', () {
    test('double from int', () => expect(LenientNum.asDouble(5), 5.0));
    test('double from double', () => expect(LenientNum.asDouble(3.14), 3.14));
    test('double from string',
        () => expect(LenientNum.asDouble('12345.67'), 12345.67));
    test('required null throws FormatException', () {
      expect(() => LenientNum.asDouble(null), throwsA(isA<FormatException>()));
    });
    test('empty string throws FormatException', () {
      expect(() => LenientNum.asDouble(''), throwsA(isA<FormatException>()));
    });
    test('garbage string throws FormatException', () {
      expect(() => LenientNum.asDouble('xyz'), throwsA(isA<FormatException>()));
    });
  });

  group('LenientNum.asDoubleOrNull', () {
    test('double from int', () => expect(LenientNum.asDoubleOrNull(10), 10.0));
    test('double from double',
        () => expect(LenientNum.asDoubleOrNull(2.5), 2.5));
    test('double from string',
        () => expect(LenientNum.asDoubleOrNull('99.9'), 99.9));
    test('null returns null',
        () => expect(LenientNum.asDoubleOrNull(null), null));
    test('empty string returns null',
        () => expect(LenientNum.asDoubleOrNull(''), null));
    test('garbage string throws FormatException', () {
      expect(() => LenientNum.asDoubleOrNull('bad'),
          throwsA(isA<FormatException>()));
    });
  });
}

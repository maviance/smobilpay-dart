import 'package:smobilpay/src/http/lenient_bool.dart';
import 'package:test/test.dart';

void main() {
  group('LenientBool.asBool', () {
    test('bool true', () => expect(LenientBool.asBool(true), isTrue));
    test('bool false', () => expect(LenientBool.asBool(false), isFalse));
    test('int 0 → false', () => expect(LenientBool.asBool(0), isFalse));
    test('int 1 → true', () => expect(LenientBool.asBool(1), isTrue));
    test('int non-zero → true', () => expect(LenientBool.asBool(42), isTrue));
    test('double 0.0 → false', () => expect(LenientBool.asBool(0.0), isFalse));
    test('double 1.5 → true', () => expect(LenientBool.asBool(1.5), isTrue));
    test('string "true"', () => expect(LenientBool.asBool('true'), isTrue));
    test('string "false"', () => expect(LenientBool.asBool('false'), isFalse));
    test('string "1"', () => expect(LenientBool.asBool('1'), isTrue));
    test('string "0"', () => expect(LenientBool.asBool('0'), isFalse));
    test('string "True" (mixed case)',
        () => expect(LenientBool.asBool('True'), isTrue));
    test('string "FALSE" (upper case)',
        () => expect(LenientBool.asBool('FALSE'), isFalse));
    test('garbage string throws FormatException', () {
      expect(() => LenientBool.asBool('yes'), throwsA(isA<FormatException>()));
    });
    test('null throws FormatException', () {
      expect(() => LenientBool.asBool(null), throwsA(isA<FormatException>()));
    });
  });

  group('LenientBool.asBoolOrNull', () {
    test('null → null', () => expect(LenientBool.asBoolOrNull(null), isNull));
    test('empty string → null',
        () => expect(LenientBool.asBoolOrNull(''), isNull));
    test('bool true → true',
        () => expect(LenientBool.asBoolOrNull(true), isTrue));
    test('bool false → false',
        () => expect(LenientBool.asBoolOrNull(false), isFalse));
    test('int 1 → true', () => expect(LenientBool.asBoolOrNull(1), isTrue));
    test('int 0 → false', () => expect(LenientBool.asBoolOrNull(0), isFalse));
    test('string "true" → true',
        () => expect(LenientBool.asBoolOrNull('true'), isTrue));
    test('string "false" → false',
        () => expect(LenientBool.asBoolOrNull('false'), isFalse));
    test('garbage string throws FormatException', () {
      expect(() => LenientBool.asBoolOrNull('garbage'),
          throwsA(isA<FormatException>()));
    });
  });
}

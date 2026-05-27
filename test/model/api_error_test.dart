import 'package:smobilpay/src/model/api_error.dart';
import 'package:test/test.dart';

void main() {
  group('ApiError.fromJson', () {
    test('parses a full envelope', () {
      final err = ApiError.fromJson({
        'respCode': 41004,
        'devMsg': 'service is not a voucher',
        'usrMsg': 'This service is not available.',
        'link': 'https://docs.example/41004',
      });
      expect(err.respCode, 41004);
      expect(err.devMsg, 'service is not a voucher');
      expect(err.usrMsg, 'This service is not available.');
      expect(err.link, 'https://docs.example/41004');
    });

    test('accepts nullable optional fields', () {
      final err = ApiError.fromJson({'respCode': 500});
      expect(err.respCode, 500);
      expect(err.devMsg, isNull);
      expect(err.usrMsg, isNull);
      expect(err.link, isNull);
    });

    test('toJson round-trips', () {
      const err = ApiError(
          respCode: 40408, devMsg: 'no verify', usrMsg: null, link: null);
      final json = err.toJson();
      expect(json['respCode'], 40408);
      expect(json['devMsg'], 'no verify');
      expect(json['usrMsg'], isNull);
    });

    test('equals + hashCode by value', () {
      const a = ApiError(respCode: 1, devMsg: 'a', usrMsg: 'b', link: 'c');
      const b = ApiError(respCode: 1, devMsg: 'a', usrMsg: 'b', link: 'c');
      const c = ApiError(respCode: 2, devMsg: 'a', usrMsg: 'b', link: 'c');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString surfaces respCode and devMsg', () {
      const err = ApiError(
          respCode: 41004, devMsg: 'mismatch', usrMsg: null, link: null);
      expect(err.toString(), contains('41004'));
      expect(err.toString(), contains('mismatch'));
    });
  });
}

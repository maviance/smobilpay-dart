import 'package:test/test.dart';
import 'package:s3p_signature/s3p_signature.dart';

void main() {
  test('S3P signature generation matches expected output for POST', () {
  final signature = HMACSignature.forPost(
    url: 'https://dev.smobilpay.com/s3p/v2/quotestd',
    queryParams: {
      's3pAuth_nonce': '634968823463411609',
      's3pAuth_signature_method': 'HMAC-SHA1',
      's3pAuth_timestamp': '1361281946',
      's3pAuth_token': 'xvz1evFS4wEEPTGEFPHBog',
    },
    body: {
      'amount': '1000',
      'payItemId': 'SPAY-DEV-958-AES-100013333-10010',
    },
  ).generate('MySecretKey');

    expect(signature, equals('1CLm+TQLwelkE+5Za+Vi+7G5M8U='));
  });

  test('S3P signature generation matches expected output for GET', () {
    final signature = HMACSignature.forGet(
      url: 'https://dev.smobilpay.com/s3p/v2/bill?serviceNumber=TestId&merchant=TESTMERC&serviceid=99999',
      queryParams: {
        's3pAuth_nonce': '634968823463411611',
        's3pAuth_signature_method': 'HMAC-SHA1',
        's3pAuth_timestamp': '1361281946',
        's3pAuth_token': 'xvz1evFS4wEEPTGEFPHBog',
      },
    ).generate('MySecretKey');

    expect(signature, equals('wff4LW5sueJe0K4Uzk7fHrjElGk='));
  });
}

import 'package:s3p_signature/s3p_signature.dart';

void main() {
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

  print('POST Signature: $signature');
}

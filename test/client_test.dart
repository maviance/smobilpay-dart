import 'package:smobilpay/smobilpay.dart';
import 'package:test/test.dart';

import '_support/fake_http_client.dart';

SmobilpayConfig _cfg(FakeHttpClient c) => SmobilpayConfig(
      baseUrl: Uri.parse('https://api.example.invalid'),
      publicKey: 'pub',
      secretKey: 'sec',
      httpClient: c,
    );

void main() {
  test('exposes five API group fields + tokens', () {
    final c = FakeHttpClient();
    final client = SmobilpayClient(config: _cfg(c));
    expect(client.verify, isNotNull);
    expect(client.masterdata, isNotNull);
    expect(client.accountValidation, isNotNull);
    expect(client.initiate, isNotNull);
    expect(client.confirm, isNotNull);
    expect(client.tokens, isNotNull);
    client.close();
  });

  test('close() is idempotent', () {
    final c = FakeHttpClient();
    final client = SmobilpayClient(config: _cfg(c));
    client.close();
    client.close(); // must not throw
  });

  test('end-to-end ping via injected fake http client', () async {
    final c = FakeHttpClient()
      ..expect(
        method: 'POST',
        url: '/oauth/token',
        statusCode: 200,
        body:
            '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
      )
      ..expect(
        method: 'GET',
        url: '/v2/ping',
        statusCode: 200,
        body:
            '{"time":"2026-05-27T13:00:00Z","version":"3.0.0","nonce":"n","key":"k"}',
      );
    final client = SmobilpayClient(config: _cfg(c));
    final pong = await client.verify.ping();
    expect(pong.version, '3.0.0');
    client.close();
  });
}

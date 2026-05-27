import 'dart:convert';

import 'package:smobilpay/src/api/verify_api.dart';
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:smobilpay/src/model/enums.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

VerifyApi _newApi(FakeHttpClient c) {
  c.expect(
    method: 'POST',
    url: '/oauth/token',
    statusCode: 200,
    body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
  );
  final cfg = SmobilpayConfig(
    baseUrl: Uri.parse('https://api.example.invalid'),
    publicKey: 'pub',
    secretKey: 'sec',
    httpClient: c,
  );
  final tokens = OAuth2TokenManager(
      httpClient: c, config: cfg, clock: () => DateTime.utc(2026, 1, 1));
  return VerifyApi(
      HttpTransport(httpClient: c, config: cfg, tokenManager: tokens));
}

void main() {
  test('ping decodes the spec example', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/ping',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('ping')),
    );
    final pong = await api.ping();
    expect(pong.version, '3.0.0');
    expect(pong.nonce, 'abc123');
    expect(pong.key, 'PUB_KEY_TEST');
    expect(pong.time, DateTime.utc(2026, 5, 27, 13));
  });

  test('account decodes', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/account',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('account')),
    );
    final a = await api.account();
    expect(a.agentName, 'Test Agent');
    expect(a.balance, 12345.67);
    expect(a.currency, 'XAF');
  });

  test('verifyTransaction requires ptn or trid', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    expect(
      () => api.verifyTransaction(),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test('verifyTransaction by ptn issues correct query', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/verifytx',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('payment_status')),
    );
    final rows = await api.verifyTransaction(ptn: 'PTN-001');
    expect(rows, hasLength(1));
    expect(rows.first.status, PaymentStatusType.success);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('ptn=PTN-001'));
    expect(url, isNot(contains('trid=')));
  });

  test('historyByDateRange formats both timestamps as ISO Z', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/historystd', statusCode: 200, body: '[]');
    await api.historyByDateRange(
      from: DateTime.utc(2026, 5, 20),
      to: DateTime.utc(2026, 5, 27),
    );
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('timestamp_from=2026-05-20'));
    expect(url, contains('timestamp_to=2026-05-27'));
  });

  test('historyByDateRange rejects reversed range', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    expect(
      () => api.historyByDateRange(
        from: DateTime.utc(2026, 5, 27),
        to: DateTime.utc(2026, 5, 20),
      ),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test('historyByPtn issues correct query', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/historystd', statusCode: 200, body: '[]');
    await api.historyByPtn('PTN-001');
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('ptn=PTN-001'));
  });

  test('historyByTrid issues correct query', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/historystd', statusCode: 200, body: '[]');
    await api.historyByTrid('TRID-1');
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('trid=TRID-1'));
  });

  test('Ping.toString contains version and nonce', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/ping',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('ping')),
    );
    final pong = await api.ping();
    expect(pong.toString(), contains('3.0.0'));
    expect(pong.toString(), contains('abc123'));
  });
}

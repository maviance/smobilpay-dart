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

  test('historyByDateRange formats both timestamps as ISO datetime Z',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/historystd', statusCode: 200, body: '[]');
    await api.historyByDateRange(
      from: DateTime.utc(2026, 5, 20),
      to: DateTime.utc(2026, 5, 27),
    );
    final url = Uri.decodeFull(c.capturedRequests[1].url.toString());
    // from: start-of-day 00:00:00Z
    expect(url, contains('timestamp_from=2026-05-20T00:00:00Z'));
    // to: end-of-day 23:59:59Z
    expect(url, contains('timestamp_to=2026-05-27T23:59:59Z'));
    // Confirm no fractional seconds (.000)
    expect(url, isNot(contains('timestamp_from=2026-05-20T00:00:00.000')));
    expect(url, isNot(contains('timestamp_to=2026-05-27T23:59:59.000')));
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

  test('Ping.toJson returns all fields', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/ping',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('ping')),
    );
    final pong = await api.ping();
    final j = pong.toJson();
    expect(j['version'], '3.0.0');
    expect(j['nonce'], 'abc123');
    expect(j['key'], 'PUB_KEY_TEST');
    expect(j['time'], isA<String>());
  });

  test('Account.toJson returns all fields', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/account',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('account')),
    );
    final a = await api.account();
    final j = a.toJson();
    expect(j['balance'], 12345.67);
    expect(j['currency'], 'XAF');
    expect(j['agentId'], 'AGT-001');
    expect(j['agentName'], 'Test Agent');
    expect(j['limitMax'], 1000000.0);
    expect(j['limitRemaining'], 987654.32);
    expect(j.containsKey('companyName'), isTrue);
    expect(j.containsKey('companyAddress'), isTrue);
    expect(j.containsKey('agentAddress'), isTrue);
  });

  test('Account.toJson accepts string-typed balance via LenientNum', () {
    final a = Account.fromJson({
      'balance': '20053',
      'currency': 'XAF',
      'key': 'K',
      'agentId': 'A1',
      'agentName': 'Agt',
      'limitMax': '500000',
      'limitRemaining': '499000',
    });
    expect(a.balance, 20053.0);
    expect(a.limitMax, 500000.0);
    expect(a.limitRemaining, 499000.0);
    final j = a.toJson();
    expect(j['balance'], 20053.0);
  });

  test('PaymentStatus.toJson returns all fields including commission',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/verifytx',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('payment_status')),
    );
    final rows = await api.verifyTransaction(ptn: 'PTN-001');
    final j = rows.first.toJson();
    expect(j['ptn'], 'PTN-001');
    expect(j['status'], 'SUCCESS');
    expect(j['priceLocalCur'], 500.0);
    expect(j['commission'], isA<Map<String, dynamic>>());
    expect(j.containsKey('timestamp'), isTrue);
    expect(j.containsKey('trid'), isTrue);
  });

  test('PaymentStatus.fromJson accepts string serviceId and string errorCode',
      () {
    final ps = PaymentStatus.fromJson({
      'ptn': 'PTN-X',
      'serviceid': '10039',
      'status': 'SUCCESS',
      'errorCode': '0',
      'priceLocalCur': '1500',
      'priceSystemCur': '1500',
    });
    expect(ps.serviceId, '10039');
    expect(ps.errorCode, 0);
    expect(ps.priceLocalCur, 1500.0);
    expect(ps.priceSystemCur, 1500.0);
  });
}

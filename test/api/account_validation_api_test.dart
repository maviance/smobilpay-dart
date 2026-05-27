import 'dart:convert';

import 'package:smobilpay/src/api/account_validation_api.dart';
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:smobilpay/src/model/enums.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

AccountValidationApi _newApi(FakeHttpClient c) {
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
  return AccountValidationApi(
      HttpTransport(httpClient: c, config: cfg, tokenManager: tokens));
}

void main() {
  // ---------------------------------------------------------------------------
  // verifyServiceNumber — HTTP shape
  // ---------------------------------------------------------------------------

  test(
      'verifyServiceNumber issues GET to /v2/verify with merchant, serviceid '
      '(lowercase), and serviceNumber query params', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/verify',
      statusCode: 200,
      body: 'true',
    );
    await api.verifyServiceNumber(
      merchant: 'MERCH01',
      serviceId: 42,
      serviceNumber: '677000001',
    );

    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('merchant=MERCH01'));
    expect(url, contains('serviceid=42'));
    expect(url, contains('serviceNumber=677000001'));
  });

  // ---------------------------------------------------------------------------
  // verifyServiceNumber — response decoding
  // ---------------------------------------------------------------------------

  test('verifyServiceNumber returns true when server returns bare true',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/verify',
      statusCode: 200,
      body: 'true',
    );
    final result = await api.verifyServiceNumber(
      merchant: 'MERCH01',
      serviceId: 42,
      serviceNumber: '677000001',
    );
    expect(result, isTrue);
  });

  test('verifyServiceNumber returns false when server returns bare false',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/verify',
      statusCode: 200,
      body: 'false',
    );
    final result = await api.verifyServiceNumber(
      merchant: 'MERCH01',
      serviceId: 42,
      serviceNumber: '677000099',
    );
    expect(result, isFalse);
  });

  // ---------------------------------------------------------------------------
  // validateAccount — HTTP shape
  // ---------------------------------------------------------------------------

  test(
      'validateAccount issues GET to /v2/validate with destination and '
      'serviceId (camelCase) query params', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/validate',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('customer_account')),
    );
    await api.validateAccount(destination: '677389120', serviceId: 7);

    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('destination=677389120'));
    // Must use camelCase serviceId, NOT lowercase serviceid
    expect(url, contains('serviceId=7'));
    expect(url, isNot(contains('serviceid=')));
  });

  // ---------------------------------------------------------------------------
  // validateAccount — response decoding
  // ---------------------------------------------------------------------------

  test('validateAccount decodes fixture into CustomerAccount', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/validate',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('customer_account')),
    );
    final account = await api.validateAccount(
      destination: '677389120',
      serviceId: 7,
    );

    expect(account.status, CustomerAccountStatus.verified);
    expect(account.name, 'JOHN DOE');
    expect(account.destination, '677389120');
  });

  // ---------------------------------------------------------------------------
  // CustomerAccount.fromJson — edge cases
  // ---------------------------------------------------------------------------

  test(
      'CustomerAccount.fromJson with missing name and destination produces '
      'null fields and unknown status when status is unrecognised', () {
    final account = CustomerAccount.fromJson({'status': 'BOGUS_STATUS'});

    expect(account.status, CustomerAccountStatus.unknown);
    expect(account.name, isNull);
    expect(account.destination, isNull);
  });
}

import 'dart:convert';

import 'package:smobilpay/src/api/confirm_api.dart';
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:smobilpay/src/model/enums.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

ConfirmApi _newApi(FakeHttpClient c) {
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
  return ConfirmApi(
      HttpTransport(httpClient: c, config: cfg, tokenManager: tokens));
}

void main() {
  // ---------------------------------------------------------------------------
  // collect — HTTP shape
  // ---------------------------------------------------------------------------

  test('collect issues POST to /v2/collectstd with correct JSON body',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'POST',
      url: '/v2/collectstd',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('collection_response')),
    );
    final request = CollectionRequest(
      quoteId: '00000000-0000-0000-0000-000000000001',
      customerPhonenumber: '+237612345678',
      customerEmailaddress: 'test@example.com',
    );
    await api.collect(request);

    // Verify HTTP method and path
    final req = c.capturedRequests[1];
    expect(req.method, 'POST');
    expect(req.url.path, contains('/v2/collectstd'));

    // Verify body: required fields present, null optionals absent
    final body = c.lastJsonBody()!;
    expect(
        body, containsPair('quoteId', '00000000-0000-0000-0000-000000000001'));
    expect(body, containsPair('customerPhonenumber', '+237612345678'));
    expect(body, containsPair('customerEmailaddress', 'test@example.com'));
    expect(body, isNot(contains('customerName')));
    expect(body, isNot(contains('trid')));
    expect(body, isNot(contains('tag')));
    expect(body, isNot(contains('callbackUrl')));
  });

  // ---------------------------------------------------------------------------
  // collect — response decoding
  // ---------------------------------------------------------------------------

  test('collect decodes fixture into CollectionResponse', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'POST',
      url: '/v2/collectstd',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('collection_response')),
    );
    final request = CollectionRequest(
      quoteId: '00000000-0000-0000-0000-000000000001',
      customerPhonenumber: '+237612345678',
      customerEmailaddress: 'test@example.com',
    );
    final resp = await api.collect(request);

    expect(resp.ptn, 'PTN-DART-SMOKE-001');
    expect(resp.status, PaymentStatusType.success);
    expect(resp.priceLocalCur, 1000.0);
    expect(resp.timestamp, DateTime.utc(2026, 5, 27, 13, 1, 23));
    expect(resp.agentBalance, 49500.0);
    expect(resp.receiptNumber, 'RCPT-1001');
    expect(resp.localCur, 'XAF');
    expect(resp.trid, 'dart-smoke-12345');
    expect(resp.pin, isNull);
    expect(resp.tag, isNull);
  });

  // ---------------------------------------------------------------------------
  // CollectionRequest — toJson with all optional fields
  // ---------------------------------------------------------------------------

  test('CollectionRequest with all optional fields emits all keys in toJson',
      () {
    final req = CollectionRequest(
      quoteId: 'qid-001',
      customerPhonenumber: '+237611111111',
      customerEmailaddress: 'full@example.com',
      customerName: 'Full Name',
      customerAddress: '1 Main St',
      customerNumber: 'CNUM-001',
      serviceNumber: 'SVC-001',
      trid: 'dart-smoke-1234567890',
      tag: 'promo',
      callbackUrl: 'https://example.com/callback',
      cdata: '{"extra":"data"}',
    );
    final map = req.toJson();

    expect(map, containsPair('quoteId', 'qid-001'));
    expect(map, containsPair('customerPhonenumber', '+237611111111'));
    expect(map, containsPair('customerEmailaddress', 'full@example.com'));
    expect(map, containsPair('customerName', 'Full Name'));
    expect(map, containsPair('customerAddress', '1 Main St'));
    expect(map, containsPair('customerNumber', 'CNUM-001'));
    expect(map, containsPair('serviceNumber', 'SVC-001'));
    expect(map, containsPair('trid', 'dart-smoke-1234567890'));
    expect(map, containsPair('tag', 'promo'));
    expect(map, containsPair('callbackUrl', 'https://example.com/callback'));
    expect(map, containsPair('cdata', '{"extra":"data"}'));
    expect(map.length, 11);
  });

  // ---------------------------------------------------------------------------
  // CollectionRequest — toJson with only required fields
  // ---------------------------------------------------------------------------

  test(
      'CollectionRequest with only required fields emits exactly 3 keys in '
      'toJson', () {
    final req = CollectionRequest(
      quoteId: 'qid-001',
      customerPhonenumber: '+237611111111',
      customerEmailaddress: 'min@example.com',
    );
    final map = req.toJson();

    expect(map.keys, hasLength(3));
    expect(map, containsPair('quoteId', 'qid-001'));
    expect(map, containsPair('customerPhonenumber', '+237611111111'));
    expect(map, containsPair('customerEmailaddress', 'min@example.com'));
  });

  // ---------------------------------------------------------------------------
  // CollectionRequest — validation errors
  // ---------------------------------------------------------------------------

  test('CollectionRequest throws SmobilpayConfigException on empty quoteId',
      () {
    expect(
      () => CollectionRequest(
        quoteId: '',
        customerPhonenumber: '+237611111111',
        customerEmailaddress: 'test@example.com',
      ),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test(
      'CollectionRequest throws SmobilpayConfigException on empty '
      'customerPhonenumber', () {
    expect(
      () => CollectionRequest(
        quoteId: 'qid-001',
        customerPhonenumber: '',
        customerEmailaddress: 'test@example.com',
      ),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test(
      'CollectionRequest throws SmobilpayConfigException on empty '
      'customerEmailaddress', () {
    expect(
      () => CollectionRequest(
        quoteId: 'qid-001',
        customerPhonenumber: '+237611111111',
        customerEmailaddress: '',
      ),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test(
      'CollectionRequest throws SmobilpayConfigException when tag exceeds '
      '50 characters', () {
    final longTag = 'a' * 51;
    expect(
      () => CollectionRequest(
        quoteId: 'qid-001',
        customerPhonenumber: '+237611111111',
        customerEmailaddress: 'test@example.com',
        tag: longTag,
      ),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test(
      'CollectionRequest throws SmobilpayConfigException when callbackUrl '
      'exceeds 255 characters', () {
    final longUrl = 'https://example.com/${'x' * 240}';
    expect(
      () => CollectionRequest(
        quoteId: 'qid-001',
        customerPhonenumber: '+237611111111',
        customerEmailaddress: 'test@example.com',
        callbackUrl: longUrl,
      ),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });
}

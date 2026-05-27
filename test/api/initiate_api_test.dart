import 'dart:convert';

import 'package:smobilpay/src/api/initiate_api.dart';
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:smobilpay/src/model/enums.dart';
import 'package:smobilpay/src/model/payment_item.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

InitiateApi _newApi(FakeHttpClient c) {
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
  return InitiateApi(
      HttpTransport(httpClient: c, config: cfg, tokenManager: tokens));
}

void main() {
  // ---------------------------------------------------------------------------
  // bills
  // ---------------------------------------------------------------------------

  test('bills issues GET with merchant, serviceid, serviceNumber in query',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/bill',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('bill')),
    );
    await api.bills(
        merchant: 'ENEO', serviceId: 10039, serviceNumber: '203157530');
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('merchant=ENEO'));
    expect(url, contains('serviceid=10039'));
    expect(url, contains('serviceNumber=203157530'));
  });

  test('bills decodes fixture; Bill is PaymentItem with correct dates',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/bill',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('bill')),
    );
    final bills = await api.bills(
        merchant: 'ENEO', serviceId: 10039, serviceNumber: '203157530');
    expect(bills, hasLength(1));
    final bill = bills.first;
    expect(bill, isA<PaymentItem>());
    expect(bill.payItemId, 'SPAY-DEV-10039-BILL-001');
    expect(bill.serviceId, 10039);
    expect(bill.merchant, 'ENEO');
    expect(bill.amountType, AmountType.fixed);
    expect(bill.amountLocalCur, 12500.0);
    expect(bill.billType, BillType.regular);
    expect(bill.payOrder, 0);
    expect(bill.serviceNumber, '203157530');
    expect(bill.billNumber, 'B-2026-03-203157530');
    expect(bill.billMonth, '03');
    expect(bill.billYear, '2026');
    expect(bill.billDate, DateTime.utc(2026, 3, 1));
    expect(bill.billDueDate, DateTime.utc(2026, 3, 31));
    expect(bill.penaltyAmount, isNull);
    expect(bill.customerNumber, isNull);
  });

  // ---------------------------------------------------------------------------
  // subscriptions
  // ---------------------------------------------------------------------------

  test('subscriptions issues GET with merchant, serviceid, serviceNumber',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/subscription',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('subscription')),
    );
    await api.subscriptions(
        merchant: 'CMSABC', serviceId: 5000, serviceNumber: '0000000101');
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('merchant=CMSABC'));
    expect(url, contains('serviceid=5000'));
    expect(url, contains('serviceNumber=0000000101'));
  });

  test('subscriptions decodes fixture', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/subscription',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('subscription')),
    );
    final subs = await api.subscriptions(
        merchant: 'CMSABC', serviceId: 5000, serviceNumber: '0000000101');
    expect(subs, hasLength(1));
    final sub = subs.first;
    expect(sub, isA<PaymentItem>());
    expect(sub.payItemId, 'SPAY-DEV-5000-SUB-001');
    expect(sub.serviceId, 5000);
    expect(sub.merchant, 'CMSABC');
    expect(sub.amountType, AmountType.fixed);
    expect(sub.amountLocalCur, 2500.0);
    expect(sub.serviceNumber, '0000000101');
    expect(sub.customerName, 'Test Customer');
    expect(sub.customerNumber, isNull);
    expect(sub.startDate, DateTime.utc(2026, 5, 1));
    expect(sub.dueDate, DateTime.utc(2026, 5, 31));
    expect(sub.endDate, DateTime.utc(2026, 12, 31));
  });

  test(
      'subscriptions throws SmobilpayConfigException when both serviceNumber '
      'and customerNumber are null', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    expect(
      () => api.subscriptions(merchant: 'CMSABC', serviceId: 5000),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  // ---------------------------------------------------------------------------
  // quote
  // ---------------------------------------------------------------------------

  test('quote POSTs {amount, payItemId} and decodes QuoteResponse', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'POST',
      url: '/v2/quotestd',
      statusCode: 200,
      body: jsonEncode(loadFixtureMap('quote_response')),
    );
    final request =
        QuoteRequest(amount: 12500, payItemId: 'SPAY-DEV-10039-BILL-001');
    final resp = await api.quote(request);
    // Verify POST body
    final body = c.lastJsonBody();
    expect(body, containsPair('amount', 12500));
    expect(body, containsPair('payItemId', 'SPAY-DEV-10039-BILL-001'));
    // Verify decoded response
    expect(resp.quoteId, '00000000-0000-0000-0000-000000000001');
    expect(resp.payItemId, 'SPAY-DEV-10039-BILL-001');
    expect(resp.expiresAt, DateTime.utc(2026, 5, 27, 13, 5));
    expect(resp.amountLocalCur, 12500.0);
    expect(resp.priceLocalCur, 12500.0);
    expect(resp.priceSystemCur, 12500.0);
    expect(resp.localCur, 'XAF');
    expect(resp.systemCur, 'XAF');
    expect(resp.promotion, isNull);
  });

  // ---------------------------------------------------------------------------
  // QuoteRequest validation
  // ---------------------------------------------------------------------------

  test('QuoteRequest throws SmobilpayConfigException on amount < 1', () {
    expect(
      () => QuoteRequest(amount: 0, payItemId: 'SPAY-DEV-10039-BILL-001'),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test('QuoteRequest throws SmobilpayConfigException on empty payItemId', () {
    expect(
      () => QuoteRequest(amount: 100, payItemId: ''),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });
}

import 'dart:convert';

import 'package:smobilpay/src/api/masterdata_api.dart';
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:smobilpay/src/model/enums.dart';
import 'package:smobilpay/src/model/i18n_text.dart';
import 'package:smobilpay/src/model/payment_item.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

MasterdataApi _newApi(FakeHttpClient c) {
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
  return MasterdataApi(
      HttpTransport(httpClient: c, config: cfg, tokenManager: tokens));
}

void main() {
  // -------------------------------------------------------------------------
  // Merchant
  // -------------------------------------------------------------------------

  test('merchants decodes fixture and issues GET /v2/merchant', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/merchant',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('merchants')),
    );
    final result = await api.merchants();
    expect(result, hasLength(1));
    final m = result.first;
    expect(m.merchant, 'ENEO');
    expect(m.name, 'Eneo Cameroon');
    expect(m.country, 'CMR');
    expect(m.status, MerchantStatus.active);
    expect(m.logo, isNull);
    expect(m.logoHash, isNull);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('/v2/merchant'));
  });

  test('merchant equality holds for identical values', () {
    const a = Merchant(
      merchant: 'X',
      name: 'X Corp',
      description: null,
      country: 'CMR',
      status: MerchantStatus.active,
      logo: null,
      logoHash: null,
    );
    const b = Merchant(
      merchant: 'X',
      name: 'X Corp',
      description: null,
      country: 'CMR',
      status: MerchantStatus.active,
      logo: null,
      logoHash: null,
    );
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  // -------------------------------------------------------------------------
  // Service
  // -------------------------------------------------------------------------

  test('services decodes fixture and issues GET /v2/service', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/service',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('services')),
    );
    final result = await api.services();
    expect(result, hasLength(1));
    final s = result.first;
    expect(s.serviceId, 10039);
    expect(s.merchant, 'ENEO');
    expect(s.title, 'Postpaid bill payment');
    expect(s.type, ServiceType.searchableBill);
    expect(s.status, ServiceStatus.active);
    expect(s.isReqServiceNumber, isTrue);
    expect(s.isReqCustomerName, isFalse);
    expect(s.isVerifiable, isTrue);
    expect(s.labelServiceNumber, hasLength(1));
    expect(
      s.labelServiceNumber.first,
      equals(const I18nText(language: 'en', localText: 'Contract number')),
    );
    expect(s.labelCustomerNumber, isEmpty);
    expect(s.hint, isEmpty);
    expect(s.denomination, isNull);
  });

  // -------------------------------------------------------------------------
  // Cashout
  // -------------------------------------------------------------------------

  test('cashouts decodes fixture and issues GET /v2/cashout', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/cashout',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('cashout')),
    );
    final result = await api.cashouts();
    expect(result, hasLength(1));
    final co = result.first;
    expect(co.serviceId, 20053);
    expect(co.merchant, 'CMMTNMOMO');
    expect(co.payItemId, 'SPAY-DEV-20053-MTN-CASHOUT-001');
    expect(co.amountType, AmountType.custom);
    expect(co.amountLocalCur, isNull);
    expect(co.localCur, 'XAF');
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('/v2/cashout'));
    expect(url, isNot(contains('serviceid=')));
  });

  test('cashouts sends serviceid query param when provided', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/cashout',
      statusCode: 200,
      body: '[]',
    );
    await api.cashouts(serviceId: 20053);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('serviceid=20053'));
  });

  test('cashout is a PaymentItem with correct interface values', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/cashout',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('cashout')),
    );
    final result = await api.cashouts();
    final co = result.first;
    expect(co, isA<PaymentItem>());
    final pi = co as PaymentItem;
    expect(pi.serviceId, 20053);
    expect(pi.merchant, 'CMMTNMOMO');
    expect(pi.payItemId, 'SPAY-DEV-20053-MTN-CASHOUT-001');
    expect(pi.payItemDescr, 'MTN Mobile Money Cash-Out');
    expect(pi.amountType, AmountType.custom);
    expect(pi.localCur, 'XAF');
    expect(pi.name, 'MTN MoMo Cash-Out');
    expect(pi.amountLocalCur, isNull);
    expect(pi.description, 'Collect from MTN MoMo wallet');
    expect(pi.optStrg, isNull);
    expect(pi.optNmb, isNull);
  });

  // -------------------------------------------------------------------------
  // Cashin
  // -------------------------------------------------------------------------

  test('cashins decodes fixture and issues GET /v2/cashin', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/cashin',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('cashin')),
    );
    final result = await api.cashins();
    expect(result, hasLength(1));
    final ci = result.first;
    expect(ci.serviceId, 20054);
    expect(ci.payItemId, 'SPAY-DEV-20054-MTN-CASHIN-001');
    expect(ci.amountType, AmountType.custom);
    expect(ci, isA<PaymentItem>());
  });

  test('cashins sends serviceid query param when provided', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/cashin', statusCode: 200, body: '[]');
    await api.cashins(serviceId: 20054);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('serviceid=20054'));
  });

  // -------------------------------------------------------------------------
  // Topup
  // -------------------------------------------------------------------------

  test('topups decodes fixture and issues GET /v2/topup', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/topup',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('topup')),
    );
    final result = await api.topups();
    expect(result, hasLength(1));
    final t = result.first;
    expect(t.serviceId, 10101);
    expect(t.merchant, 'CMOMRNG');
    expect(t.amountType, AmountType.custom);
    expect(t, isA<PaymentItem>());
  });

  test('topups sends serviceid query param when provided', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/topup', statusCode: 200, body: '[]');
    await api.topups(serviceId: 10101);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('serviceid=10101'));
  });

  // -------------------------------------------------------------------------
  // Product (products + vouchers)
  // -------------------------------------------------------------------------

  test('products decodes fixture with FIXED amountType and non-null amount',
      () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/product',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('product')),
    );
    final result = await api.products();
    expect(result, hasLength(1));
    final p = result.first;
    expect(p.serviceId, 30201);
    expect(p.merchant, 'CMSCRATCH');
    expect(p.amountType, AmountType.fixed);
    expect(p.amountLocalCur, 500.0);
    expect(p, isA<PaymentItem>());
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('/v2/product'));
  });

  test('products sends serviceid query param when provided', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/product', statusCode: 200, body: '[]');
    await api.products(serviceId: 30201);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('serviceid=30201'));
  });

  test('vouchers issues GET /v2/voucher and decodes Product shape', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET',
      url: '/v2/voucher',
      statusCode: 200,
      body: jsonEncode(loadFixtureList('product')),
    );
    final result = await api.vouchers();
    expect(result, hasLength(1));
    expect(result.first, isA<Product>());
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('/v2/voucher'));
  });

  test('vouchers sends serviceid query param when provided', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/voucher', statusCode: 200, body: '[]');
    await api.vouchers(serviceId: 30201);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('serviceid=30201'));
  });

  // -------------------------------------------------------------------------
  // Merchant — toString, inequality
  // -------------------------------------------------------------------------

  test('merchant.toString contains merchant code and name', () {
    const m = Merchant(
      merchant: 'ENEO',
      name: 'Eneo Cameroon',
      description: null,
      country: 'CMR',
      status: MerchantStatus.active,
      logo: null,
      logoHash: null,
    );
    expect(m.toString(), contains('ENEO'));
    expect(m.toString(), contains('Eneo Cameroon'));
  });

  test('merchant inequality when status differs', () {
    const a = Merchant(
      merchant: 'X',
      name: 'X Corp',
      description: null,
      country: 'CMR',
      status: MerchantStatus.active,
      logo: null,
      logoHash: null,
    );
    const b = Merchant(
      merchant: 'X',
      name: 'X Corp',
      description: null,
      country: 'CMR',
      status: MerchantStatus.inactive,
      logo: null,
      logoHash: null,
    );
    expect(a, isNot(equals(b)));
  });

  // -------------------------------------------------------------------------
  // Cashout — equality, hashCode, toString
  // -------------------------------------------------------------------------

  test('Cashout equality by value', () {
    const a = Cashout(
      serviceId: 20053,
      merchant: 'CMMTNMOMO',
      payItemId: 'SPAY-DEV-20053-MTN-CASHOUT-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Cashout(
      serviceId: 20053,
      merchant: 'CMMTNMOMO',
      payItemId: 'SPAY-DEV-20053-MTN-CASHOUT-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('Cashout inequality when merchant differs', () {
    const a = Cashout(
      serviceId: 20053,
      merchant: 'CMMTNMOMO',
      payItemId: 'SPAY-DEV-20053-MTN-CASHOUT-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Cashout(
      serviceId: 20053,
      merchant: 'OTHER',
      payItemId: 'SPAY-DEV-20053-MTN-CASHOUT-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, isNot(equals(b)));
  });

  test('Cashout.toString contains payItemId and amountType', () {
    const co = Cashout(
      serviceId: 20053,
      merchant: 'CMMTNMOMO',
      payItemId: 'SPAY-DEV-20053-MTN-CASHOUT-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(co.toString(), contains('SPAY-DEV-20053-MTN-CASHOUT-001'));
    expect(co.toString(), contains('AmountType'));
  });

  // -------------------------------------------------------------------------
  // Cashin — equality, hashCode, toString
  // -------------------------------------------------------------------------

  test('Cashin equality by value', () {
    const a = Cashin(
      serviceId: 20054,
      merchant: 'CMMTNMOMO',
      payItemId: 'SPAY-DEV-20054-MTN-CASHIN-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Cashin(
      serviceId: 20054,
      merchant: 'CMMTNMOMO',
      payItemId: 'SPAY-DEV-20054-MTN-CASHIN-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('Cashin inequality when serviceId differs', () {
    const a = Cashin(
      serviceId: 20054,
      merchant: 'CMMTNMOMO',
      payItemId: 'X',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Cashin(
      serviceId: 20055,
      merchant: 'CMMTNMOMO',
      payItemId: 'X',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, isNot(equals(b)));
  });

  test('Cashin.toString contains payItemId', () {
    const ci = Cashin(
      serviceId: 20054,
      merchant: 'CMMTNMOMO',
      payItemId: 'SPAY-DEV-20054-MTN-CASHIN-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(ci.toString(), contains('SPAY-DEV-20054-MTN-CASHIN-001'));
  });

  // -------------------------------------------------------------------------
  // Topup — equality, hashCode, toString
  // -------------------------------------------------------------------------

  test('Topup equality by value', () {
    const a = Topup(
      serviceId: 10101,
      merchant: 'CMOMRNG',
      payItemId: 'SPAY-DEV-10101-TOPUP-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Topup(
      serviceId: 10101,
      merchant: 'CMOMRNG',
      payItemId: 'SPAY-DEV-10101-TOPUP-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('Topup inequality when payItemId differs', () {
    const a = Topup(
      serviceId: 10101,
      merchant: 'CMOMRNG',
      payItemId: 'SPAY-DEV-10101-TOPUP-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Topup(
      serviceId: 10101,
      merchant: 'CMOMRNG',
      payItemId: 'SPAY-DEV-10101-TOPUP-002',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, isNot(equals(b)));
  });

  test('Topup.toString contains payItemId', () {
    const t = Topup(
      serviceId: 10101,
      merchant: 'CMOMRNG',
      payItemId: 'SPAY-DEV-10101-TOPUP-001',
      payItemDescr: null,
      amountType: AmountType.custom,
      localCur: 'XAF',
      name: null,
      amountLocalCur: null,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(t.toString(), contains('SPAY-DEV-10101-TOPUP-001'));
  });

  // -------------------------------------------------------------------------
  // Product — equality, hashCode, toString
  // -------------------------------------------------------------------------

  test('Product equality by value', () {
    const a = Product(
      serviceId: 30201,
      merchant: 'CMSCRATCH',
      payItemId: 'SPAY-DEV-30201-PROD-001',
      payItemDescr: null,
      amountType: AmountType.fixed,
      localCur: 'XAF',
      name: null,
      amountLocalCur: 500.0,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Product(
      serviceId: 30201,
      merchant: 'CMSCRATCH',
      payItemId: 'SPAY-DEV-30201-PROD-001',
      payItemDescr: null,
      amountType: AmountType.fixed,
      localCur: 'XAF',
      name: null,
      amountLocalCur: 500.0,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('Product inequality when amountLocalCur differs', () {
    const a = Product(
      serviceId: 30201,
      merchant: 'CMSCRATCH',
      payItemId: 'SPAY-DEV-30201-PROD-001',
      payItemDescr: null,
      amountType: AmountType.fixed,
      localCur: 'XAF',
      name: null,
      amountLocalCur: 500.0,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    const b = Product(
      serviceId: 30201,
      merchant: 'CMSCRATCH',
      payItemId: 'SPAY-DEV-30201-PROD-001',
      payItemDescr: null,
      amountType: AmountType.fixed,
      localCur: 'XAF',
      name: null,
      amountLocalCur: 1000.0,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(a, isNot(equals(b)));
  });

  test('Product.toString contains payItemId', () {
    const p = Product(
      serviceId: 30201,
      merchant: 'CMSCRATCH',
      payItemId: 'SPAY-DEV-30201-PROD-001',
      payItemDescr: null,
      amountType: AmountType.fixed,
      localCur: 'XAF',
      name: null,
      amountLocalCur: 500.0,
      description: null,
      optStrg: null,
      optNmb: null,
    );
    expect(p.toString(), contains('SPAY-DEV-30201-PROD-001'));
  });
}

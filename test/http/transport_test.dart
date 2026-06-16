import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/http/query_params.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

SmobilpayConfig _cfg(http.Client client) => SmobilpayConfig(
      baseUrl: Uri.parse('https://api.example.invalid'),
      publicKey: 'pub',
      secretKey: 'sec',
      httpClient: client,
    );

OAuth2TokenManager _tokens(http.Client client, SmobilpayConfig cfg) =>
    OAuth2TokenManager(
      httpClient: client,
      config: cfg,
      clock: () => DateTime.utc(2026, 1, 1),
    );

void _expectTokenMint(FakeHttpClient c) {
  c.expect(
    method: 'POST',
    url: '/oauth/token',
    statusCode: 200,
    body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
  );
}

void main() {
  group('getJson', () {
    test('issues GET with bearer + version + accept headers', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'GET',
        url: '/v2/ping',
        statusCode: 200,
        body: jsonEncode(loadFixtureMap('ping')),
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      final body = await t.getJson('/v2/ping', QueryParams());
      expect((body as Map<String, dynamic>)['version'], '3.0.0');
      final req = c.capturedRequests[1];
      expect(req.method, 'GET');
      expect(req.url.path, '/v2/ping');
      expect(req.headers['Authorization'], 'Bearer jwt.A');
      expect(req.headers['x-api-version'], '3.0.0');
      expect(req.headers['Accept'], 'application/json');
    });

    test('appends query string', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(method: 'GET', url: '/v2/bill?', statusCode: 200, body: '[]');
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await t.getJson(
        '/v2/bill',
        QueryParams()
          ..add('merchant', 'ENEO')
          ..add('serviceid', 10039),
      );
      final url = c.capturedRequests[1].url.toString();
      expect(url, contains('?merchant=ENEO'));
      expect(url, contains('serviceid=10039'));
    });
  });

  group('postJson', () {
    test('sends JSON body with Content-Type', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'POST',
        url: '/v2/quotestd',
        statusCode: 200,
        body: '{"quoteId":"00000000-0000-0000-0000-000000000000"}',
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await t.postJson('/v2/quotestd', {'amount': 1000, 'payItemId': 'X'});
      final req = c.capturedRequests[1] as http.Request;
      expect(req.headers['Content-Type'], 'application/json');
      expect(jsonDecode(req.body), {'amount': 1000, 'payItemId': 'X'});
    });
  });

  group('errors', () {
    test('decodes ApiError envelope on 4xx', () async {
      // Use 404 (not 401) so this exercises envelope decoding without
      // triggering the reactive token-refresh retry; 401 has its own group.
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'GET',
        url: '/v2/ping',
        statusCode: 404,
        body: jsonEncode(loadFixtureMap('api_error')),
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayApiException>()
            .having((e) => e.httpStatus, 'status', 404)
            .having((e) => e.error?.respCode, 'respCode', 41004)),
      );
    });

    test('falls back to rawBody when error body is not JSON', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'GET',
        url: '/v2/ping',
        statusCode: 500,
        body: 'Internal Server Error',
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayApiException>()
            .having((e) => e.httpStatus, 'status', 500)
            .having((e) => e.error, 'error', isNull)
            .having((e) => e.rawBody, 'rawBody', 'Internal Server Error')),
      );
    });

    test('decodes ApiError with string respCode on 4xx', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'GET',
        url: '/v2/ping',
        statusCode: 400,
        body: jsonEncode(loadFixtureMap('api_error_string_respcode')),
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayApiException>()
            .having((e) => e.httpStatus, 'status', 400)
            .having((e) => e.error?.respCode, 'respCode', 40408)
            .having((e) => e.error?.devMsg, 'devMsg',
                'Verification is not supported for this service')),
      );
    });

    test('throws SmobilpayTransportException on malformed 2xx JSON', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
          method: 'GET', url: '/v2/ping', statusCode: 200, body: 'not json');
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayTransportException>()),
      );
    });
  });

  group('auth retry on 401', () {
    test('refreshes token and retries once on 401, then succeeds', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c); // initial mint -> jwt.A
      c.expect(method: 'GET', url: '/v2/ping', statusCode: 401, body: '');
      c.expect(
        method: 'POST',
        url: '/oauth/token',
        statusCode: 200,
        body: '{"access_token":"jwt.B","token_type":"Bearer","expires_in":3600}',
      );
      c.expect(
        method: 'GET',
        url: '/v2/ping',
        statusCode: 200,
        body: jsonEncode(loadFixtureMap('ping')),
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));

      final body = await t.getJson('/v2/ping', QueryParams());

      expect((body as Map<String, dynamic>)['version'], '3.0.0');
      // mint -> ping(401) -> re-mint -> ping(200)
      expect(c.capturedRequests.length, 4);
      expect(c.capturedRequests[1].headers['Authorization'], 'Bearer jwt.A');
      expect(c.capturedRequests[2].method, 'POST');
      expect(c.capturedRequests[2].url.path, '/oauth/token');
      expect(c.capturedRequests[3].headers['Authorization'], 'Bearer jwt.B');
    });

    test('retries at most once — surfaces 401 when the retry also 401s',
        () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(method: 'GET', url: '/v2/ping', statusCode: 401, body: '');
      c.expect(
        method: 'POST',
        url: '/oauth/token',
        statusCode: 200,
        body: '{"access_token":"jwt.B","token_type":"Bearer","expires_in":3600}',
      );
      c.expect(
        method: 'GET',
        url: '/v2/ping',
        statusCode: 401,
        body: jsonEncode(loadFixtureMap('api_error')),
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));

      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayApiException>()
            .having((e) => e.httpStatus, 'status', 401)),
      );
      // exactly one retry: mint -> ping -> re-mint -> ping
      expect(c.capturedRequests.length, 4);
    });

    test('retries POST on 401 with the refreshed bearer and same body',
        () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(method: 'POST', url: '/v2/quotestd', statusCode: 401, body: '');
      c.expect(
        method: 'POST',
        url: '/oauth/token',
        statusCode: 200,
        body: '{"access_token":"jwt.B","token_type":"Bearer","expires_in":3600}',
      );
      c.expect(
        method: 'POST',
        url: '/v2/quotestd',
        statusCode: 200,
        body: '{"quoteId":"00000000-0000-0000-0000-000000000000"}',
      );
      final cfg = _cfg(c);
      final t = HttpTransport(
          httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));

      final body =
          await t.postJson('/v2/quotestd', {'amount': 1000, 'payItemId': 'X'});

      expect((body as Map<String, dynamic>)['quoteId'],
          '00000000-0000-0000-0000-000000000000');
      final retry = c.capturedRequests[3] as http.Request;
      expect(retry.headers['Authorization'], 'Bearer jwt.B');
      expect(jsonDecode(retry.body), {'amount': 1000, 'payItemId': 'X'});
    });
  });
}

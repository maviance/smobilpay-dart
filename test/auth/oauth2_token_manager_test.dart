import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:test/test.dart';

import '../_support/fake_clock.dart';
import '../_support/fake_http_client.dart';

SmobilpayConfig _cfg(http.Client client) => SmobilpayConfig(
      baseUrl: Uri.parse('https://api.example.invalid'),
      publicKey: 'pub',
      secretKey: 'sec',
      tokenRefreshSkew: const Duration(seconds: 30),
      httpClient: client,
    );

void main() {
  group('accessToken', () {
    test('mints, caches, returns the bearer', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body:
              '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1, 12),
      );
      expect(await mgr.accessToken(), 'jwt.A');
      expect(await mgr.accessToken(), 'jwt.A');
      expect(c.capturedRequests, hasLength(1));
    });

    test('sends Basic auth + form body', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body: '{"access_token":"x","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await mgr.accessToken();
      final req = c.latestRequest;
      expect(req.headers['Authorization'], startsWith('Basic '));
      final basic = req.headers['Authorization']!.substring(6);
      expect(String.fromCharCodes(base64Decode(basic)), 'pub:sec');
      expect(req.headers['Content-Type'], 'application/x-www-form-urlencoded');
      expect(c.lastFormBody(), {'grant_type': 'client_credentials'});
    });

    test('re-mints once now+skew >= expiresAt', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body:
              '{"access_token":"jwt.A","token_type":"Bearer","expires_in":60}',
        )
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body:
              '{"access_token":"jwt.B","token_type":"Bearer","expires_in":60}',
        );
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: clock.call,
      );
      expect(await mgr.accessToken(), 'jwt.A');
      clock.advance(const Duration(seconds: 35));
      expect(await mgr.accessToken(), 'jwt.B');
      expect(c.capturedRequests, hasLength(2));
    });

    test('defaults token_type to Bearer when missing', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body: '{"access_token":"jwt.A","expires_in":60}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await mgr.accessToken();
      expect(mgr.cached?.tokenType, 'Bearer');
    });

    test('concurrent callers dedupe to a single mint', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body:
              '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      final results = await Future.wait([
        mgr.accessToken(),
        mgr.accessToken(),
        mgr.accessToken(),
      ]);
      expect(results, ['jwt.A', 'jwt.A', 'jwt.A']);
      expect(c.capturedRequests, hasLength(1));
    });
  });

  group('refresh', () {
    test('forces a fresh mint and replaces the cache', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body:
              '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
        )
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body:
              '{"access_token":"jwt.B","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      expect(await mgr.accessToken(), 'jwt.A');
      expect(await mgr.refresh(), 'jwt.B');
      expect(await mgr.accessToken(), 'jwt.B');
    });
  });

  group('failure modes', () {
    test('non-2xx throws SmobilpayAuthException with oauthError', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 401,
          body: '{"error":"invalid_client"}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(
        mgr.accessToken(),
        throwsA(isA<SmobilpayAuthException>()
            .having((e) => e.httpStatus, 'status', 401)
            .having((e) => e.oauthError, 'oauthError', 'invalid_client')),
      );
    });

    test('missing access_token throws', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body: '{"expires_in":60}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(
          mgr.accessToken(), throwsA(isA<SmobilpayAuthException>()));
    });

    test('missing expires_in throws', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body: '{"access_token":"jwt.A"}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(
          mgr.accessToken(), throwsA(isA<SmobilpayAuthException>()));
    });

    test('non-JSON body throws', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST',
          url: '/oauth/token',
          statusCode: 200,
          body: 'not json',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(
          mgr.accessToken(), throwsA(isA<SmobilpayAuthException>()));
    });
  });
}

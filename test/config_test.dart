import 'package:http/http.dart' as http;
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:test/test.dart';

void main() {
  group('SmobilpayConfig', () {
    test('accepts a minimal valid config and exposes defaults', () {
      final cfg = SmobilpayConfig(
        baseUrl: Uri.parse('https://api.example.invalid'),
        publicKey: 'pub',
        secretKey: 'sec',
      );
      expect(cfg.baseUrl, Uri.parse('https://api.example.invalid'));
      expect(cfg.publicKey, 'pub');
      expect(cfg.secretKey, 'sec');
      expect(cfg.apiVersion, '3.0.0');
      expect(cfg.requestTimeout, const Duration(seconds: 30));
      expect(cfg.tokenRefreshSkew, const Duration(seconds: 30));
      expect(cfg.httpClient, isNull);
    });

    test('normalises trailing slash on baseUrl', () {
      final cfg = SmobilpayConfig(
        baseUrl: Uri.parse('https://api.example.invalid/'),
        publicKey: 'p',
        secretKey: 's',
      );
      expect(cfg.baseUrl.toString(), 'https://api.example.invalid');
    });

    test('throws on empty publicKey', () {
      expect(
        () => SmobilpayConfig(
          baseUrl: Uri.parse('https://api.example.invalid'),
          publicKey: '',
          secretKey: 's',
        ),
        throwsA(isA<SmobilpayConfigException>()),
      );
    });

    test('throws on empty secretKey', () {
      expect(
        () => SmobilpayConfig(
          baseUrl: Uri.parse('https://api.example.invalid'),
          publicKey: 'p',
          secretKey: '',
        ),
        throwsA(isA<SmobilpayConfigException>()),
      );
    });

    test('throws on non-http(s) scheme', () {
      expect(
        () => SmobilpayConfig(
          baseUrl: Uri.parse('ftp://api.example.invalid'),
          publicKey: 'p',
          secretKey: 's',
        ),
        throwsA(isA<SmobilpayConfigException>()),
      );
    });

    test('accepts injected http.Client', () {
      final client = http.Client();
      try {
        final cfg = SmobilpayConfig(
          baseUrl: Uri.parse('https://api.example.invalid'),
          publicKey: 'p',
          secretKey: 's',
          httpClient: client,
        );
        expect(cfg.httpClient, same(client));
      } finally {
        client.close();
      }
    });

    test('accepts custom apiVersion/timeout/skew', () {
      final cfg = SmobilpayConfig(
        baseUrl: Uri.parse('https://api.example.invalid'),
        publicKey: 'p',
        secretKey: 's',
        apiVersion: '2.2.0',
        requestTimeout: const Duration(seconds: 5),
        tokenRefreshSkew: const Duration(seconds: 10),
      );
      expect(cfg.apiVersion, '2.2.0');
      expect(cfg.requestTimeout, const Duration(seconds: 5));
      expect(cfg.tokenRefreshSkew, const Duration(seconds: 10));
    });
  });
}

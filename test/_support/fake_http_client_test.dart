import 'package:test/test.dart';

import 'fake_clock.dart';
import 'fake_http_client.dart';
import 'fixtures.dart';

void main() {
  group('FakeHttpClient', () {
    test('returns canned response when method+url match', () async {
      final c = FakeHttpClient()
        ..expect(
            method: 'GET', url: '/v2/ping', statusCode: 200, body: '{"v":1}');
      final res = await c.get(Uri.parse('https://api.example/v2/ping'));
      expect(res.statusCode, 200);
      expect(res.body, '{"v":1}');
      expect(c.capturedRequests, hasLength(1));
    });

    test('throws StateError when no expectation matches', () async {
      final c = FakeHttpClient();
      expect(() => c.get(Uri.parse('https://api.example/v2/ping')),
          throwsA(isA<StateError>()));
    });

    test('parses form-encoded body', () async {
      final c = FakeHttpClient()
        ..expect(
            method: 'POST', url: '/oauth/token', statusCode: 200, body: '{}');
      await c.post(
        Uri.parse('https://api.example/oauth/token'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=client_credentials',
      );
      expect(c.lastFormBody(), {'grant_type': 'client_credentials'});
    });
  });

  group('FakeClock', () {
    test('returns current value and advances', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      expect(clock(), DateTime.utc(2026, 1, 1, 12));
      clock.advance(const Duration(minutes: 5));
      expect(clock(), DateTime.utc(2026, 1, 1, 12, 5));
    });
  });

  group('loadFixture', () {
    test('loads api_error.json', () {
      final json = loadFixtureMap('api_error');
      expect(json['respCode'], 41004);
      expect(json['devMsg'], contains('VOUCHER'));
    });
  });
}

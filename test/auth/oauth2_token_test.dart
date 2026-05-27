import 'package:smobilpay/src/auth/oauth2_token.dart';
import 'package:test/test.dart';

void main() {
  group('OAuth2Token', () {
    test('stores all fields', () {
      final t = OAuth2Token(
        accessToken: 'jwt.xyz',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(t.accessToken, 'jwt.xyz');
      expect(t.tokenType, 'Bearer');
      expect(t.expiresAt, DateTime.utc(2026, 1, 1, 12));
    });

    test('isExpired false when now + skew is before expiresAt', () {
      final t = OAuth2Token(
        accessToken: 'x',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(
          t.isExpired(
              DateTime.utc(2026, 1, 1, 11), const Duration(seconds: 30)),
          isFalse);
    });

    test('isExpired true when now + skew == expiresAt', () {
      final t = OAuth2Token(
        accessToken: 'x',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12, 0, 30),
      );
      expect(
          t.isExpired(
              DateTime.utc(2026, 1, 1, 12), const Duration(seconds: 30)),
          isTrue);
    });

    test('isExpired true after expiry', () {
      final t = OAuth2Token(
        accessToken: 'x',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(
          t.isExpired(DateTime.utc(2026, 1, 1, 12, 1), Duration.zero), isTrue);
    });

    test('equality by value', () {
      final t1 = OAuth2Token(
          accessToken: 'a',
          tokenType: 'Bearer',
          expiresAt: DateTime.utc(2026, 1, 1));
      final t2 = OAuth2Token(
          accessToken: 'a',
          tokenType: 'Bearer',
          expiresAt: DateTime.utc(2026, 1, 1));
      expect(t1, equals(t2));
      expect(t1.hashCode, t2.hashCode);
    });

    test('toString contains tokenType and expiresAt year', () {
      final t = OAuth2Token(
        accessToken: 'jwt.xyz',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(t.toString(), contains('Bearer'));
      expect(t.toString(), contains('2026'));
    });

    test('inequality when accessToken differs', () {
      final t1 = OAuth2Token(
          accessToken: 'a',
          tokenType: 'Bearer',
          expiresAt: DateTime.utc(2026, 1, 1));
      final t2 = OAuth2Token(
          accessToken: 'b',
          tokenType: 'Bearer',
          expiresAt: DateTime.utc(2026, 1, 1));
      expect(t1, isNot(equals(t2)));
    });
  });
}

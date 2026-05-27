import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/model/api_error.dart';
import 'package:test/test.dart';

void main() {
  group('SmobilpayException hierarchy', () {
    test('is sealed and exhaustively switchable', () {
      final exceptions = <SmobilpayException>[
        SmobilpayApiException.fromEnvelope(500, null, '<empty>'),
        const SmobilpayAuthException(401, 'invalid_client', null, 'no creds'),
        SmobilpayTransportException('GET /v2/ping', Exception('eof'), 'eof'),
        const SmobilpayConfigException('bad baseUrl'),
      ];
      for (final e in exceptions) {
        final summary = switch (e) {
          SmobilpayApiException() => 'api',
          SmobilpayAuthException() => 'auth',
          SmobilpayTransportException() => 'transport',
          SmobilpayConfigException() => 'config',
        };
        expect(summary, isNotEmpty);
      }
    });

    test(
        'SmobilpayApiException formats message with respCode when error present',
        () {
      const err = ApiError(
          respCode: 41004,
          devMsg: 'service mismatch',
          usrMsg: null,
          link: null);
      final e =
          SmobilpayApiException.fromEnvelope(404, err, '{"respCode":41004}');
      expect(e.httpStatus, 404);
      expect(e.error, same(err));
      expect(e.rawBody, '{"respCode":41004}');
      expect(e.message, contains('41004'));
      expect(e.message, contains('service mismatch'));
    });

    test('SmobilpayApiException without error falls back to raw body', () {
      final e = SmobilpayApiException.fromEnvelope(500, null, '<plain text>');
      expect(e.error, isNull);
      expect(e.message, contains('500'));
      expect(e.message, contains('<plain text>'));
    });

    test('SmobilpayAuthException carries httpStatus + oauthError + cause', () {
      final cause = Exception('eof');
      final e =
          SmobilpayAuthException(401, 'invalid_client', cause, 'rejected');
      expect(e.httpStatus, 401);
      expect(e.oauthError, 'invalid_client');
      expect(e.cause, same(cause));
    });

    test('SmobilpayTransportException carries operation + cause', () {
      final cause = Exception('eof');
      final e = SmobilpayTransportException('POST /v2/quotestd', cause, 'eof');
      expect(e.operation, 'POST /v2/quotestd');
      expect(e.cause, same(cause));
    });

    test('SmobilpayConfigException implements Exception', () {
      const e = SmobilpayConfigException('baseUrl is required');
      expect(e, isA<Exception>());
      expect(e.message, 'baseUrl is required');
    });

    test('SmobilpayException.toString includes runtimeType and message', () {
      const e = SmobilpayConfigException('bad config');
      expect(e.toString(), contains('SmobilpayConfigException'));
      expect(e.toString(), contains('bad config'));
    });

    test(
        'SmobilpayApiException.fromEnvelope with empty rawBody uses placeholder',
        () {
      final e = SmobilpayApiException.fromEnvelope(503, null, '');
      expect(e.message, contains('<empty body>'));
      expect(e.message, contains('503'));
    });

    test(
        'SmobilpayApiException.fromEnvelope with null rawBody uses placeholder',
        () {
      final e = SmobilpayApiException.fromEnvelope(503, null, null);
      expect(e.message, contains('<empty body>'));
    });

    test(
        'SmobilpayApiException.fromEnvelope with error but null devMsg uses '
        'placeholder', () {
      const err =
          ApiError(respCode: 500, devMsg: null, usrMsg: null, link: null);
      final e = SmobilpayApiException.fromEnvelope(500, err, null);
      expect(e.message, contains('<no devMsg>'));
      expect(e.message, contains('500'));
    });
  });
}

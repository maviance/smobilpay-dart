import 'model/api_error.dart';

/// Base for every exception thrown by the Smobilpay client.
///
/// The hierarchy is `sealed`, so consumers can exhaustively `switch` on
/// the concrete subtype with no `default` branch.
sealed class SmobilpayException implements Exception {
  /// Creates a [SmobilpayException].
  const SmobilpayException(this.message);

  /// Human-readable diagnostic.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the API returns a non-2xx response.
final class SmobilpayApiException extends SmobilpayException {
  /// Creates a [SmobilpayApiException] with an explicit message.
  const SmobilpayApiException(
      this.httpStatus, this.error, this.rawBody, String message)
      : super(message);

  /// Builds a [SmobilpayApiException] from HTTP status + envelope, deriving
  /// a default message.
  factory SmobilpayApiException.fromEnvelope(
      int httpStatus, ApiError? error, String? rawBody) {
    final message = error != null
        ? 'Smobilpay API error (HTTP $httpStatus, respCode=${error.respCode}): ${error.devMsg ?? "<no devMsg>"}'
        : 'Smobilpay API error (HTTP $httpStatus): '
            '${rawBody == null || rawBody.isEmpty ? "<empty body>" : rawBody}';
    return SmobilpayApiException(httpStatus, error, rawBody, message);
  }

  /// HTTP status code.
  final int httpStatus;

  /// Decoded `{respCode, devMsg, usrMsg, link}` envelope, or null when the
  /// response body was not a parseable envelope.
  final ApiError? error;

  /// Raw response body for diagnostics when [error] is null.
  final String? rawBody;
}

/// Thrown when OAuth 2.0 token issuance fails.
final class SmobilpayAuthException extends SmobilpayException {
  /// Creates a [SmobilpayAuthException].
  const SmobilpayAuthException(
      this.httpStatus, this.oauthError, this.cause, String message)
      : super(message);

  /// HTTP status. `0` means network failure (no response received).
  final int httpStatus;

  /// OAuth 2.0 standard error identifier (e.g. `invalid_client`), or null.
  final String? oauthError;

  /// Underlying cause, if any.
  final Object? cause;
}

/// Thrown when a transport-level error occurs — connection refused, EOF,
/// timeout, malformed JSON in a 2xx response, etc.
final class SmobilpayTransportException extends SmobilpayException {
  /// Creates a [SmobilpayTransportException].
  const SmobilpayTransportException(this.operation, this.cause, String message)
      : super(message);

  /// Operation that was attempted (e.g. `GET /v2/ping`).
  final String operation;

  /// Underlying cause.
  final Object cause;
}

/// Thrown when configuration or API arguments are invalid.
final class SmobilpayConfigException extends SmobilpayException {
  /// Creates a [SmobilpayConfigException].
  const SmobilpayConfigException(super.message);
}

/// Standard API error envelope. Full implementation lives in Task 4 — this
/// stub exists so the exception hierarchy can be tested first.
class ApiError {
  /// Creates an [ApiError].
  const ApiError({
    required this.respCode,
    required this.devMsg,
    required this.usrMsg,
    required this.link,
  });

  /// Unique error response code.
  final int respCode;

  /// Verbose, plain-language description for the integrator.
  final String? devMsg;

  /// High-level, user-safe error message.
  final String? usrMsg;

  /// URI to documentation for this error code.
  final String? link;
}

/// Immutable OAuth 2.0 access token returned by `POST /oauth/token`.
class OAuth2Token {
  /// Creates an [OAuth2Token].
  const OAuth2Token({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
  });

  /// JWT bearer string. Sent as `Authorization: Bearer <accessToken>`.
  final String accessToken;

  /// OAuth 2.0 token type. Always `Bearer` in practice.
  final String tokenType;

  /// Absolute moment at which this token stops being valid.
  /// Computed at mint time as `issuedAt + expires_in seconds`.
  final DateTime expiresAt;

  /// Returns `true` when [now] plus [skew] is at or past [expiresAt].
  bool isExpired(DateTime now, Duration skew) =>
      !now.add(skew).isBefore(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OAuth2Token &&
          accessToken == other.accessToken &&
          tokenType == other.tokenType &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(accessToken, tokenType, expiresAt);

  @override
  String toString() =>
      'OAuth2Token(tokenType: $tokenType, expiresAt: $expiresAt)';
}

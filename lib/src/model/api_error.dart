/// Standard API error envelope returned by the partner API on non-2xx
/// responses.
///
/// Match programmatically on [respCode] — it is the canonical machine
/// identifier per the partner spec. [devMsg] is integrator-facing,
/// [usrMsg] is user-safe.
class ApiError {
  /// Creates an [ApiError].
  const ApiError({
    required this.respCode,
    required this.devMsg,
    required this.usrMsg,
    required this.link,
  });

  /// Decodes an [ApiError] from a JSON map.
  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        respCode: (json['respCode'] as num).toInt(),
        devMsg: json['devMsg'] as String?,
        usrMsg: json['usrMsg'] as String?,
        link: json['link'] as String?,
      );

  /// Unique error response code identifying the issue.
  final int respCode;

  /// Verbose, plain-language description for the integrator.
  final String? devMsg;

  /// High-level, user-safe error message.
  final String? usrMsg;

  /// URI to documentation for this error code.
  final String? link;

  /// Encodes this [ApiError] as a JSON map.
  Map<String, dynamic> toJson() => {
        'respCode': respCode,
        'devMsg': devMsg,
        'usrMsg': usrMsg,
        'link': link,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiError &&
          respCode == other.respCode &&
          devMsg == other.devMsg &&
          usrMsg == other.usrMsg &&
          link == other.link;

  @override
  int get hashCode => Object.hash(respCode, devMsg, usrMsg, link);

  @override
  String toString() =>
      'ApiError(respCode: $respCode, devMsg: $devMsg, usrMsg: $usrMsg, link: $link)';
}

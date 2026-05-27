import 'package:http/http.dart' as http;

import 'exception.dart';

/// Configuration for a [SmobilpayClient].
///
/// Throws [SmobilpayConfigException] for invalid input.
class SmobilpayConfig {
  /// Creates a [SmobilpayConfig].
  factory SmobilpayConfig({
    required Uri baseUrl,
    required String publicKey,
    required String secretKey,
    String apiVersion = defaultApiVersion,
    Duration requestTimeout = defaultRequestTimeout,
    Duration tokenRefreshSkew = defaultTokenRefreshSkew,
    http.Client? httpClient,
  }) {
    if (baseUrl.scheme != 'http' && baseUrl.scheme != 'https') {
      throw SmobilpayConfigException(
        'baseUrl scheme must be http or https, got "${baseUrl.scheme}"',
      );
    }
    if (publicKey.isEmpty) {
      throw const SmobilpayConfigException('publicKey must not be empty');
    }
    if (secretKey.isEmpty) {
      throw const SmobilpayConfigException('secretKey must not be empty');
    }
    return SmobilpayConfig._(
      baseUrl: _stripTrailingSlash(baseUrl),
      publicKey: publicKey,
      secretKey: secretKey,
      apiVersion: apiVersion,
      requestTimeout: requestTimeout,
      tokenRefreshSkew: tokenRefreshSkew,
      httpClient: httpClient,
    );
  }

  const SmobilpayConfig._({
    required this.baseUrl,
    required this.publicKey,
    required this.secretKey,
    required this.apiVersion,
    required this.requestTimeout,
    required this.tokenRefreshSkew,
    required this.httpClient,
  });

  /// Default `x-api-version` header value mandated by the partner spec.
  static const String defaultApiVersion = '3.0.0';

  /// Default per-request timeout.
  static const Duration defaultRequestTimeout = Duration(seconds: 30);

  /// Default refresh-ahead window for cached OAuth tokens.
  static const Duration defaultTokenRefreshSkew = Duration(seconds: 30);

  /// Partner API base URL with any trailing slash stripped.
  final Uri baseUrl;

  /// OAuth 2.0 client identifier.
  final String publicKey;

  /// OAuth 2.0 client secret.
  final String secretKey;

  /// Value of the `x-api-version` request header on every secured call.
  final String apiVersion;

  /// Per-request timeout applied to outbound calls.
  final Duration requestTimeout;

  /// Refresh-ahead window — tokens within this many seconds of expiry are
  /// treated as expired so the next call mints a fresh one.
  final Duration tokenRefreshSkew;

  /// Optional injected HTTP client. `null` → [SmobilpayClient] owns one.
  final http.Client? httpClient;

  static Uri _stripTrailingSlash(Uri url) {
    final s = url.toString();
    if (s.endsWith('/')) return Uri.parse(s.substring(0, s.length - 1));
    return url;
  }
}

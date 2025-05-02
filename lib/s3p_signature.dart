import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Represents a simple name-value pair used in signing.
class Pair {
  final String name;
  final String value;

  Pair(this.name, this.value);
}

/// A utility for generating Smobilpay S3P HMAC-SHA1 signatures.
class HMACSignature {
  final String method;
  final String url;
  final List<Pair> params;

  /// Core constructor (used internally). Use [forPost] or [forGet] instead.
  HMACSignature({
    required this.method,
    required this.url,
    required this.params,
  });

  /// Named constructor for POST requests.
  /// Accepts query parameters and body fields (e.g., form or JSON payload).
  factory HMACSignature.forPost({
    required String url,
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) {
    return HMACSignature(
      method: 'POST',
      url: url,
      params: [
        ..._mapToPairs(queryParams ?? {}),
        ...bodyConverter(body ?? {}),
      ],
    );
  }

  /// Named constructor for GET requests.
  /// Automatically extracts query parameters from the URL and merges them with any provided explicitly.
  factory HMACSignature.forGet({
    required String url,
    Map<String, String>? queryParams,
  }) {
    final uri = Uri.parse(url);
    final mergedParams = {
      ...uri.queryParameters,
      ...?queryParams,
    };

    // FIX: remove trailing ? if no query parameters left
    final cleanedUrl = uri
        .replace(queryParameters: {})
        .toString()
        .replaceAll(RegExp(r'\?$'), '');

    return HMACSignature(
      method: 'GET',
      url: cleanedUrl,
      params: _mapToPairs(mergedParams),
    );
  }

  /// Generates the Base64-encoded HMAC-SHA1 signature using the provided secret key.
  String generate(String accessSecret) {
    final baseString = getBaseString();
    print('Base String: $baseString');
    return _calculateHMACInBase64(baseString, accessSecret);
  }

  /// Assembles the signature base string.
  String getBaseString() {
    const glue = '&';
    return method.trim().toUpperCase() +
        glue +
        _percentEncode(url.trim()) +
        glue +
        _percentEncode(getParameterString());
  }

  /// Builds the canonicalized parameter string: sorted key=value pairs joined with '&'.
  String getParameterString() {
    final paramList = params.map((p) => '${p.name}=${p.value}').toList()
      ..sort();
    return paramList.join('&').trim();
  }

  /// Percent-encodes a string as per RFC 3986.
  String _percentEncode(String input) {
    return Uri.encodeComponent(input).replaceAll('+', '%20');
  }

  /// Applies HMAC-SHA1 to the base string using the access secret and encodes it in Base64.
  String _calculateHMACInBase64(String data, String key) {
    final hmacSha1 = Hmac(sha1, utf8.encode(key));
    final digest = hmacSha1.convert(utf8.encode(data));
    return base64.encode(digest.bytes);
  }

  /// Converts a map into a list of [Pair]s.
  static List<Pair> _mapToPairs(Map<String, dynamic> map) {
    return map.entries.map((e) => Pair(e.key, e.value.toString())).toList();
  }

  /// Converts a request body (Map) into a list of [Pair]s.
  static List<Pair> bodyConverter(Map<String, dynamic> body) {
    return _mapToPairs(body);
  }
}

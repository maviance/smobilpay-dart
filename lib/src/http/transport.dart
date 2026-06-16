import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/oauth2_token_manager.dart';
import '../config.dart';
import '../exception.dart';
import '../model/api_error.dart';
import 'query_params.dart';

/// Request/response engine. Adds auth + `x-api-version` headers, applies
/// the per-request timeout, decodes the JSON body or throws a typed
/// exception for non-2xx responses.
class HttpTransport {
  /// Creates a transport.
  HttpTransport({
    required http.Client httpClient,
    required SmobilpayConfig config,
    required OAuth2TokenManager tokenManager,
  })  : _httpClient = httpClient,
        _config = config,
        _tokenManager = tokenManager;

  final http.Client _httpClient;
  final SmobilpayConfig _config;
  final OAuth2TokenManager _tokenManager;

  /// Issues an authenticated `GET` and returns the decoded JSON.
  Future<dynamic> getJson(String path, QueryParams query) async {
    final uri = _resolve(path, query);
    final op = 'GET ${_canonicalPath(path)}';
    final resp = await _send(
      op,
      (bearer) => _httpClient.get(uri, headers: _headers(bearer)),
    );
    return _decode(resp, op);
  }

  /// Issues an authenticated `POST` of a JSON [body] and returns the decoded JSON.
  Future<dynamic> postJson(String path, Object body) async {
    final uri = _resolve(path, QueryParams());
    final op = 'POST ${_canonicalPath(path)}';
    final resp = await _send(
      op,
      (bearer) => _httpClient.post(
        uri,
        headers: {
          ..._headers(bearer),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
    return _decode(resp, op);
  }

  /// Sends an authenticated request built by [issue], retrying once on a
  /// `401` after forcing a token refresh.
  ///
  /// The cached access token is checked against the client's local clock, but
  /// the server is the real authority on validity: clock drift, server-side
  /// revocation, key rotation, or an auth-service restart can all make the
  /// server reject a bearer the client still believes is valid. A `401` is
  /// returned at the auth layer before any business logic runs, so a single
  /// refresh-and-retry is safe even for non-idempotent POSTs (no double-charge
  /// risk). The retry is bounded to one attempt: a still-`401` response — for
  /// example a genuinely restricted endpoint such as `/v2/validate` — falls
  /// through to [_decode] and surfaces as a typed [SmobilpayApiException].
  Future<http.Response> _send(
    String op,
    Future<http.Response> Function(String bearer) issue,
  ) async {
    final bearer = await _tokenManager.accessToken();
    final resp = await _dispatch(op, () => issue(bearer));
    if (resp.statusCode != 401) return resp;
    final refreshed = await _tokenManager.refresh();
    return _dispatch(op, () => issue(refreshed));
  }

  /// Awaits a single HTTP attempt under the configured timeout, mapping any
  /// transport-level error to a [SmobilpayTransportException].
  Future<http.Response> _dispatch(
    String op,
    Future<http.Response> Function() attempt,
  ) async {
    try {
      return await attempt().timeout(_config.requestTimeout);
    } catch (e) {
      throw SmobilpayTransportException(op, e, '$op failed: $e');
    }
  }

  Map<String, String> _headers(String bearer) => {
        'Authorization': 'Bearer $bearer',
        'x-api-version': _config.apiVersion,
        'Accept': 'application/json',
      };

  Uri _resolve(String path, QueryParams query) {
    final p = _canonicalPath(path);
    final url = '${_config.baseUrl}$p';
    final q = query.toQuery();
    return Uri.parse(q.isEmpty ? url : '$url?$q');
  }

  String _canonicalPath(String p) => p.startsWith('/') ? p : '/$p';

  dynamic _decode(http.Response resp, String op) {
    final status = resp.statusCode;
    if (status < 200 || status >= 300) {
      ApiError? error;
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> &&
            decoded.containsKey('respCode')) {
          error = ApiError.fromJson(decoded);
        }
      } catch (_) {/* not an envelope */}
      throw SmobilpayApiException.fromEnvelope(status, error, resp.body);
    }
    if (resp.body.isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } catch (e) {
      throw SmobilpayTransportException(
          op, e, '$op: failed to parse JSON response: $e');
    }
  }
}

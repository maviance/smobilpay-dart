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
    final bearer = await _tokenManager.accessToken();
    final uri = _resolve(path, query);
    final op = 'GET ${_canonicalPath(path)}';
    final http.Response resp;
    try {
      resp = await _httpClient
          .get(uri, headers: _headers(bearer))
          .timeout(_config.requestTimeout);
    } catch (e) {
      throw SmobilpayTransportException(op, e, '$op failed: $e');
    }
    return _decode(resp, op);
  }

  /// Issues an authenticated `POST` of a JSON [body] and returns the decoded JSON.
  Future<dynamic> postJson(String path, Object body) async {
    final bearer = await _tokenManager.accessToken();
    final uri = _resolve(path, QueryParams());
    final op = 'POST ${_canonicalPath(path)}';
    final http.Response resp;
    try {
      resp = await _httpClient
          .post(
            uri,
            headers: {
              ..._headers(bearer),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_config.requestTimeout);
    } catch (e) {
      throw SmobilpayTransportException(op, e, '$op failed: $e');
    }
    return _decode(resp, op);
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
        if (decoded is Map<String, dynamic> && decoded['respCode'] is num) {
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

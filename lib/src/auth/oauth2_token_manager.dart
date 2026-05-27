import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../exception.dart';
import 'oauth2_token.dart';

/// Mints, caches, and refreshes OAuth 2.0 access tokens via
/// `POST /oauth/token` using `client_credentials`.
///
/// Concurrent callers are de-duplicated through a `Completer`-guarded
/// mutex — only one mint at a time; losing callers `await` the same
/// `Future<OAuth2Token>`.
class OAuth2TokenManager {
  /// Creates a token manager.
  ///
  /// [clock] defaults to [DateTime.now]; inject a fake for deterministic tests.
  OAuth2TokenManager({
    required http.Client httpClient,
    required SmobilpayConfig config,
    DateTime Function()? clock,
  })  : _httpClient = httpClient,
        _config = config,
        _clock = clock ?? DateTime.now;

  static const String _tokenPath = '/oauth/token';
  static const String _grantBody = 'grant_type=client_credentials';

  final http.Client _httpClient;
  final SmobilpayConfig _config;
  final DateTime Function() _clock;

  OAuth2Token? _current;
  Completer<OAuth2Token>? _inFlight;

  /// Currently-cached token, or `null` if never minted.
  OAuth2Token? get cached => _current;

  /// Returns a valid bearer string, minting on cache miss or expiry.
  ///
  /// Concurrent calls while a mint is in progress share a single HTTP request.
  Future<String> accessToken() async {
    final snap = _current;
    if (snap != null && !snap.isExpired(_clock(), _config.tokenRefreshSkew)) {
      return snap.accessToken;
    }
    final tok = await _mintCached();
    return tok.accessToken;
  }

  /// Forces a fresh mint, replacing any cached token, and returns the new
  /// bearer string.
  Future<String> refresh() async {
    final tok = await _mintForce();
    return tok.accessToken;
  }

  // Returns the in-flight future if a mint is already running, otherwise
  // delegates to [_mintForce].
  Future<OAuth2Token> _mintCached() async {
    final pending = _inFlight;
    if (pending != null) return pending.future;
    return _mintForce();
  }

  // Starts a new mint, sets up the Completer guard, stores the result, and
  // clears the guard when done (whether success or failure).
  Future<OAuth2Token> _mintForce() async {
    final completer = Completer<OAuth2Token>();
    // Suppress unhandled-error noise if no concurrent caller ever awaits
    // the completer's future directly.
    completer.future.ignore();
    _inFlight = completer;
    try {
      final tok = await _doMint();
      _current = tok;
      completer.complete(tok);
      return tok;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  // Performs the actual HTTP request and parses the response.
  Future<OAuth2Token> _doMint() async {
    final uri = _config.baseUrl.replace(path: _tokenPath);
    final basic = base64Encode(
      utf8.encode('${_config.publicKey}:${_config.secretKey}'),
    );
    final issuedAt = _clock();
    final http.Response resp;
    try {
      resp = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Basic $basic',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: _grantBody,
          )
          .timeout(_config.requestTimeout);
    } catch (e) {
      throw SmobilpayAuthException(
        0,
        null,
        e,
        'POST /oauth/token failed: $e',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final oauthError = _tryReadOAuthErrorCode(resp.body);
      throw SmobilpayAuthException(
        resp.statusCode,
        oauthError,
        null,
        'OAuth token mint failed (HTTP ${resp.statusCode}'
        '${oauthError != null ? ", error=$oauthError" : ""})'
        '${resp.body.isEmpty ? "" : ": ${resp.body}"}',
      );
    }

    return _parseTokenResponse(resp.body, issuedAt);
  }

  OAuth2Token _parseTokenResponse(String body, DateTime issuedAt) {
    Map<String, dynamic> node;
    try {
      node = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw SmobilpayAuthException(
        200,
        null,
        e,
        'OAuth token response was not valid JSON: $e',
      );
    }

    final accessToken = node['access_token'];
    final expiresIn = node['expires_in'];

    if (accessToken is! String || accessToken.isEmpty) {
      throw const SmobilpayAuthException(
        200,
        null,
        null,
        "OAuth token response missing required field 'access_token'",
      );
    }
    if (expiresIn is! num) {
      throw const SmobilpayAuthException(
        200,
        null,
        null,
        "OAuth token response missing required field 'expires_in'",
      );
    }

    final tokenType =
        node['token_type'] is String ? node['token_type'] as String : 'Bearer';

    return OAuth2Token(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresAt: issuedAt.add(Duration(seconds: expiresIn.toInt())),
    );
  }

  String? _tryReadOAuthErrorCode(String body) {
    if (body.isEmpty) return null;
    try {
      final n = jsonDecode(body);
      if (n is Map<String, dynamic> && n['error'] is String) {
        return n['error'] as String;
      }
    } catch (_) {
      // body wasn't JSON — ignore
    }
    return null;
  }
}

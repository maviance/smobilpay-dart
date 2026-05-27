import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Canned-response [http.Client] for unit tests.
///
/// Register expectations with [expect] keyed by `(method, urlPattern)`.
/// On `send`, the first registered expectation whose method matches and
/// whose `urlPattern` is contained in the request URL wins, is removed
/// from the queue, and its body is returned to the caller. A `send` with
/// no matching expectation throws [StateError].
class FakeHttpClient extends http.BaseClient {
  final List<_Expectation> _expectations = [];
  final List<http.BaseRequest> _captured = [];

  /// Every request seen by this client, in order.
  List<http.BaseRequest> get capturedRequests => List.unmodifiable(_captured);

  /// Latest captured request, cast to [http.Request] for body inspection.
  http.Request get latestRequest => _captured.last as http.Request;

  /// Registers an expected response.
  void expect({
    required String method,
    required String url,
    required int statusCode,
    String body = '',
    Map<String, String> headers = const {'content-type': 'application/json'},
  }) {
    _expectations.add(
      _Expectation(method.toUpperCase(), url, statusCode, body, headers),
    );
  }

  /// Decodes the latest request body as a JSON map, or returns null when empty.
  Map<String, dynamic>? lastJsonBody() {
    final body = latestRequest.body;
    if (body.isEmpty) return null;
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Decodes the latest request body as a form-encoded map.
  Map<String, String> lastFormBody() {
    final body = latestRequest.body;
    if (body.isEmpty) return const {};
    return Uri.splitQueryString(body);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _captured.add(request);
    final method = request.method.toUpperCase();
    final url = request.url.toString();
    final idx = _expectations.indexWhere(
      (e) => e.method == method && url.contains(e.urlPattern),
    );
    if (idx < 0) {
      throw StateError(
        'FakeHttpClient: no expectation matched $method $url\n'
        'Registered: ${_expectations.map((e) => "${e.method} ${e.urlPattern}").join(", ")}',
      );
    }
    final exp = _expectations.removeAt(idx);
    final bytes = utf8.encode(exp.body);
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      exp.statusCode,
      contentLength: bytes.length,
      headers: exp.headers,
      request: request,
    );
  }
}

class _Expectation {
  const _Expectation(
      this.method, this.urlPattern, this.statusCode, this.body, this.headers);

  final String method;
  final String urlPattern;
  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

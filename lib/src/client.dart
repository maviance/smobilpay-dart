import 'package:http/http.dart' as http;

import 'api/account_validation_api.dart';
import 'api/confirm_api.dart';
import 'api/initiate_api.dart';
import 'api/masterdata_api.dart';
import 'api/verify_api.dart';
import 'auth/oauth2_token_manager.dart';
import 'config.dart';
import 'http/transport.dart';

/// Entry point for the Smobilpay partner API.
///
/// Construct a client with [SmobilpayConfig]; the client lazily mints an
/// OAuth 2.0 bearer on the first authenticated request and caches it
/// until expiry. Call [close] when finished to release the HTTP client.
class SmobilpayClient {
  /// Creates a [SmobilpayClient].
  factory SmobilpayClient({required SmobilpayConfig config}) {
    final injected = config.httpClient;
    final httpClient = injected ?? http.Client();
    final tokens = OAuth2TokenManager(httpClient: httpClient, config: config);
    final transport = HttpTransport(
      httpClient: httpClient,
      config: config,
      tokenManager: tokens,
    );
    return SmobilpayClient._(
      httpClient: httpClient,
      ownsHttpClient: injected == null,
      tokens: tokens,
      masterdata: MasterdataApi(transport),
      accountValidation: AccountValidationApi(transport),
      initiate: InitiateApi(transport),
      confirm: ConfirmApi(transport),
      verify: VerifyApi(transport),
    );
  }

  SmobilpayClient._({
    required http.Client httpClient,
    required bool ownsHttpClient,
    required this.tokens,
    required this.masterdata,
    required this.accountValidation,
    required this.initiate,
    required this.confirm,
    required this.verify,
  })  : _httpClient = httpClient,
        _ownsHttpClient = ownsHttpClient;

  /// Static reference data (merchants, services, payment items).
  final MasterdataApi masterdata;

  /// Pre-payment account checks (`verify`, `validate`).
  final AccountValidationApi accountValidation;

  /// Lookups and quotes that prepare a payment collection.
  final InitiateApi initiate;

  /// Executes a payment collection against a quote.
  final ConfirmApi confirm;

  /// Status and account verification.
  final VerifyApi verify;

  /// OAuth 2.0 token diagnostics (`refresh()`, `cached`).
  final OAuth2TokenManager tokens;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  bool _closed = false;

  /// Releases resources. Closes the internal `http.Client` if this client
  /// created it. Calling more than once is a no-op.
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsHttpClient) _httpClient.close();
  }
}

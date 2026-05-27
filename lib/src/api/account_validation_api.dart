import '../http/query_params.dart';
import '../http/transport.dart';
import '../model/enums.dart';

/// Pre-payment account checks. Backed by the `Account Validation` spec tag.
class AccountValidationApi {
  /// Creates an [AccountValidationApi].
  AccountValidationApi(this._transport);

  final HttpTransport _transport;

  /// `GET /v2/verify` — verifies that a service number is valid for the
  /// selected service. Only meaningful for services that report
  /// `isVerifiable: true`.
  ///
  /// Returns `true` if the service number is valid. The wire response is a
  /// bare JSON boolean literal.
  Future<bool> verifyServiceNumber({
    required String merchant,
    required int serviceId,
    required String serviceNumber,
  }) async {
    final raw = await _transport.getJson(
      '/v2/verify',
      QueryParams()
        ..add('merchant', merchant)
        ..add('serviceid', serviceId)
        ..add('serviceNumber', serviceNumber),
    );
    return raw as bool;
  }

  /// `GET /v2/validate` — validates an account by destination (typically an
  /// MSISDN or contract number) and retrieves the associated customer name
  /// when available.
  ///
  /// **Restricted endpoint.** Partners without compliance clearance receive
  /// HTTP 401 as a `SmobilpayApiException`.
  Future<CustomerAccount> validateAccount({
    required String destination,
    required int serviceId,
  }) async {
    final json = await _transport.getJson(
      '/v2/validate',
      QueryParams()
        ..add('destination', destination)
        ..add('serviceId', serviceId),
    ) as Map<String, dynamic>;
    return CustomerAccount.fromJson(json);
  }
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// Result of `GET /v2/validate` — an account-lookup response that reports
/// whether the supplied `destination` is recognized by the service and,
/// where available, the associated customer name.
class CustomerAccount {
  /// Creates a [CustomerAccount].
  const CustomerAccount({
    required this.status,
    this.name,
    this.destination,
  });

  /// Decodes from JSON.
  factory CustomerAccount.fromJson(Map<String, dynamic> json) =>
      CustomerAccount(
        status: enumFromJson(
          CustomerAccountStatus.values,
          json['status'] as String?,
          fallback: CustomerAccountStatus.unknown,
        )!,
        name: json['name'] as String?,
        destination: json['destination'] as String?,
      );

  /// Account-recognition outcome.
  final CustomerAccountStatus status;

  /// Customer name when available; null when KYC data is unavailable.
  final String? name;

  /// The destination MSISDN/account echoed back; may be null per spec.
  final String? destination;

  /// Encodes this [CustomerAccount] as a JSON map.
  Map<String, dynamic> toJson() => {
        'destination': destination,
        'name': name,
        'status': status.wireName,
      };
}

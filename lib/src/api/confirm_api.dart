import '../exception.dart';
import '../http/lenient_date.dart';
import '../http/transport.dart';
import '../model/enums.dart';

/// Execute payment collections against a previously-issued quote.
/// Backed by the `Confirm` spec tag.
class ConfirmApi {
  /// Creates a [ConfirmApi].
  ConfirmApi(this._transport);

  final HttpTransport _transport;

  /// `POST /v2/collectstd` — execute a payment collection against a valid
  /// (unexpired) quote.
  ///
  /// A `498` response from the server indicates the quote has expired; re-quote
  /// before retrying.
  Future<CollectionResponse> collect(CollectionRequest request) async {
    final json = await _transport.postJson('/v2/collectstd', request.toJson())
        as Map<String, dynamic>;
    return CollectionResponse.fromJson(json);
  }
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// Request body for `POST /v2/collectstd`.
///
/// [quoteId], [customerPhonenumber], and [customerEmailaddress] are required
/// and validated in the constructor. All other fields are optional.
///
/// Throws [SmobilpayConfigException] when:
/// - Any required field is null or empty.
/// - [tag] exceeds 50 characters.
/// - [callbackUrl] exceeds 255 characters.
class CollectionRequest {
  /// Creates a [CollectionRequest], validating required fields and length
  /// constraints.
  CollectionRequest({
    required this.quoteId,
    required this.customerPhonenumber,
    required this.customerEmailaddress,
    this.customerName,
    this.customerAddress,
    this.customerNumber,
    this.serviceNumber,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  }) {
    if (quoteId.isEmpty) {
      throw const SmobilpayConfigException('quoteId must not be empty');
    }
    if (customerPhonenumber.isEmpty) {
      throw const SmobilpayConfigException(
          'customerPhonenumber must not be empty');
    }
    if (customerEmailaddress.isEmpty) {
      throw const SmobilpayConfigException(
          'customerEmailaddress must not be empty');
    }
    if (tag != null && tag!.length > 50) {
      throw SmobilpayConfigException(
          'tag exceeds 50-character limit: length=${tag!.length}');
    }
    if (callbackUrl != null && callbackUrl!.length > 255) {
      throw SmobilpayConfigException(
          'callbackUrl exceeds 255-character limit: length=${callbackUrl!.length}');
    }
  }

  /// Unique quote identifier previously issued by `POST /v2/quotestd`.
  final String quoteId;

  /// Customer phone number — wire key is `customerPhonenumber`.
  final String customerPhonenumber;

  /// Customer e-mail address.
  final String customerEmailaddress;

  /// Customer display name, if required by the service.
  final String? customerName;

  /// Customer mailing address, if required by the service.
  final String? customerAddress;

  /// Customer account/member number, if required by the service.
  final String? customerNumber;

  /// Subscriber service number (meter/account), if required by the service.
  final String? serviceNumber;

  /// Caller-assigned transaction reference (idempotency key).
  final String? trid;

  /// Free-form label (max 50 characters).
  final String? tag;

  /// Webhook URL to be notified when the collection completes (max 255 chars).
  final String? callbackUrl;

  /// Custom data passed through to webhook notifications.
  final String? cdata;

  /// Encodes to a JSON map for the wire body.
  ///
  /// Only non-null fields are included — the server rejects explicit nulls on
  /// optional fields for some integrations.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'quoteId': quoteId,
      'customerPhonenumber': customerPhonenumber,
      'customerEmailaddress': customerEmailaddress,
    };
    if (customerName != null) map['customerName'] = customerName;
    if (customerAddress != null) map['customerAddress'] = customerAddress;
    if (customerNumber != null) map['customerNumber'] = customerNumber;
    if (serviceNumber != null) map['serviceNumber'] = serviceNumber;
    if (trid != null) map['trid'] = trid;
    if (tag != null) map['tag'] = tag;
    if (callbackUrl != null) map['callbackUrl'] = callbackUrl;
    if (cdata != null) map['cdata'] = cdata;
    return map;
  }

  @override
  String toString() => 'CollectionRequest(quoteId: $quoteId, '
      'customerPhonenumber: $customerPhonenumber)';
}

/// Response from `POST /v2/collectstd` confirming a payment collection.
///
/// [ptn] is globally unique across the platform.
/// [receiptNumber] is scoped to the agent and is not globally unique.
/// [pin] carries a digital-voucher PIN when the service delivers one.
class CollectionResponse {
  /// Creates a [CollectionResponse].
  const CollectionResponse({
    required this.ptn,
    required this.status,
    this.timestamp,
    this.agentBalance,
    this.receiptNumber,
    this.veriCode,
    this.priceLocalCur,
    this.priceSystemCur,
    this.localCur,
    this.systemCur,
    this.trid,
    this.pin,
    this.payItemId,
    this.payItemDescr,
    this.tag,
  });

  /// Decodes from JSON.
  factory CollectionResponse.fromJson(Map<String, dynamic> json) =>
      CollectionResponse(
        ptn: json['ptn'] as String,
        status: enumFromJson(
          PaymentStatusType.values,
          json['status'] as String?,
          fallback: PaymentStatusType.unknown,
        )!,
        timestamp: LenientDate.parseOrNull(json['timestamp'] as String?),
        agentBalance: (json['agentBalance'] as num?)?.toDouble(),
        receiptNumber: json['receiptNumber'] as String?,
        veriCode: json['veriCode'] as String?,
        priceLocalCur: (json['priceLocalCur'] as num?)?.toDouble(),
        priceSystemCur: (json['priceSystemCur'] as num?)?.toDouble(),
        localCur: json['localCur'] as String?,
        systemCur: json['systemCur'] as String?,
        trid: json['trid'] as String?,
        pin: json['pin'] as String?,
        payItemId: json['payItemId'] as String?,
        payItemDescr: json['payItemDescr'] as String?,
        tag: json['tag'] as String?,
      );

  /// Platform transaction number — globally unique.
  final String ptn;

  /// Final payment processing status.
  final PaymentStatusType status;

  /// UTC instant the collection was processed by the platform.
  final DateTime? timestamp;

  /// Remaining agent float balance after this collection, in local currency.
  final double? agentBalance;

  /// Agent-scoped receipt number.
  final String? receiptNumber;

  /// Verification code for customer confirmation.
  final String? veriCode;

  /// Amount collected in local currency.
  final double? priceLocalCur;

  /// Amount collected in system currency.
  final double? priceSystemCur;

  /// Local currency (ISO 4217).
  final String? localCur;

  /// System currency (ISO 4217).
  final String? systemCur;

  /// Caller-assigned transaction reference echoed back.
  final String? trid;

  /// Digital-voucher PIN delivered when the service type is a voucher.
  final String? pin;

  /// Payment item identifier.
  final String? payItemId;

  /// Payment item display description.
  final String? payItemDescr;

  /// Free-form label echoed back from the request.
  final String? tag;

  @override
  String toString() => 'CollectionResponse(ptn: $ptn, status: $status, '
      'priceLocalCur: $priceLocalCur)';
}

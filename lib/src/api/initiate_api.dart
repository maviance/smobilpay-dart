import '../exception.dart';
import '../http/lenient_date.dart';
import '../http/query_params.dart';
import '../http/transport.dart';
import '../model/enums.dart';
import '../model/payment_item.dart';

/// Lookup and quote endpoints that prepare a payment collection.
/// Backed by the `Initiate` spec tag.
class InitiateApi {
  /// Creates an [InitiateApi].
  InitiateApi(this._transport);

  final HttpTransport _transport;

  /// `GET /v2/bill` — search open bills for a service number.
  ///
  /// For `SEARCHABLE_BILL` services the response may contain multiple bills;
  /// for `NON_SEARCHABLE_BILL` services it always returns a single item.
  Future<List<Bill>> bills({
    required String merchant,
    required int serviceId,
    required String serviceNumber,
  }) async {
    final json = await _transport.getJson(
      '/v2/bill',
      QueryParams()
        ..add('merchant', merchant)
        ..add('serviceid', serviceId)
        ..add('serviceNumber', serviceNumber),
    ) as List<dynamic>;
    return json.map((e) => Bill.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /v2/subscription` — search subscriptions by service or customer
  /// number.
  ///
  /// At least one of [serviceNumber] or [customerNumber] must be provided;
  /// throws [SmobilpayConfigException] if both are `null`.
  Future<List<Subscription>> subscriptions({
    required String merchant,
    required int serviceId,
    String? serviceNumber,
    String? customerNumber,
  }) async {
    if (serviceNumber == null && customerNumber == null) {
      throw const SmobilpayConfigException(
        'either serviceNumber or customerNumber must be provided',
      );
    }
    final json = await _transport.getJson(
      '/v2/subscription',
      QueryParams()
        ..add('merchant', merchant)
        ..add('serviceid', serviceId)
        ..add('serviceNumber', serviceNumber)
        ..add('customerNumber', customerNumber),
    ) as List<dynamic>;
    return json
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /v2/quotestd` — request a price quote for a payment collection.
  ///
  /// The returned [QuoteResponse.quoteId] must be passed to the collection
  /// request before [QuoteResponse.expiresAt].
  Future<QuoteResponse> quote(QuoteRequest request) async {
    final json = await _transport.postJson('/v2/quotestd', request.toJson())
        as Map<String, dynamic>;
    return QuoteResponse.fromJson(json);
  }
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// A bill payment item returned by `GET /v2/bill`.
///
/// For `SEARCHABLE_BILL` services the response contains every open bill for
/// the provided service number; for `NON_SEARCHABLE_BILL` services it always
/// contains a single bill.
class Bill implements PaymentItem {
  /// Creates a [Bill].
  const Bill({
    required this.serviceId,
    required this.merchant,
    required this.payItemId,
    required this.payItemDescr,
    required this.amountType,
    required this.localCur,
    required this.name,
    required this.amountLocalCur,
    required this.description,
    required this.optStrg,
    required this.optNmb,
    required this.billType,
    required this.penaltyAmount,
    required this.payOrder,
    required this.serviceNumber,
    required this.billNumber,
    required this.customerNumber,
    required this.billMonth,
    required this.billYear,
    required this.billDate,
    required this.billDueDate,
  });

  /// Decodes from JSON.
  ///
  /// The wire key is `serviceid` (lowercase i, per the partner spec).
  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        serviceId: (json['serviceid'] as num).toInt(),
        merchant: json['merchant'] as String,
        payItemId: json['payItemId'] as String,
        payItemDescr: json['payItemDescr'] as String?,
        amountType: enumFromJson(
          AmountType.values,
          json['amountType'] as String?,
          fallback: AmountType.unknown,
        )!,
        localCur: json['localCur'] as String?,
        name: json['name'] as String?,
        amountLocalCur: (json['amountLocalCur'] as num?)?.toDouble(),
        description: json['description'] as String?,
        optStrg: json['optStrg'] as String?,
        optNmb: (json['optNmb'] as num?)?.toDouble(),
        billType: enumFromJson(
          BillType.values,
          json['billType'] as String?,
          fallback: BillType.unknown,
        )!,
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble(),
        payOrder: (json['payOrder'] as num?)?.toInt() ?? 0,
        serviceNumber: json['serviceNumber'] as String?,
        billNumber: json['billNumber'] as String?,
        customerNumber: json['customerNumber'] as String?,
        billMonth: json['billMonth'] as String?,
        billYear: json['billYear'] as String?,
        billDate: LenientDate.parseOrNull(json['billDate'] as String?),
        billDueDate: LenientDate.parseOrNull(json['billDueDate'] as String?),
      );

  @override
  final int serviceId;

  @override
  final String merchant;

  @override
  final String payItemId;

  @override
  final String? payItemDescr;

  @override
  final AmountType amountType;

  @override
  final String? localCur;

  @override
  final String? name;

  @override
  final double? amountLocalCur;

  @override
  final String? description;

  @override
  final String? optStrg;

  @override
  final double? optNmb;

  /// Whether this is a regular or overdue bill.
  final BillType billType;

  /// Penalty amount applied to overdue bills, if any.
  final double? penaltyAmount;

  /// Payment ordering hint when multiple bills exist for the same service.
  final int payOrder;

  /// Subscriber's service number (meter/account number).
  final String? serviceNumber;

  /// Bill reference number as assigned by the merchant.
  final String? billNumber;

  /// Customer account number, if applicable.
  final String? customerNumber;

  /// Month component of the billing period (e.g. `"03"`).
  final String? billMonth;

  /// Year component of the billing period (e.g. `"2026"`).
  final String? billYear;

  /// Date the bill was issued.
  final DateTime? billDate;

  /// Date the bill is due for payment.
  final DateTime? billDueDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bill &&
          serviceId == other.serviceId &&
          merchant == other.merchant &&
          payItemId == other.payItemId &&
          payItemDescr == other.payItemDescr &&
          amountType == other.amountType &&
          localCur == other.localCur &&
          name == other.name &&
          amountLocalCur == other.amountLocalCur &&
          description == other.description &&
          optStrg == other.optStrg &&
          optNmb == other.optNmb &&
          billType == other.billType &&
          penaltyAmount == other.penaltyAmount &&
          payOrder == other.payOrder &&
          serviceNumber == other.serviceNumber &&
          billNumber == other.billNumber &&
          customerNumber == other.customerNumber &&
          billMonth == other.billMonth &&
          billYear == other.billYear &&
          billDate == other.billDate &&
          billDueDate == other.billDueDate;

  @override
  int get hashCode => Object.hashAll([
        serviceId,
        merchant,
        payItemId,
        payItemDescr,
        amountType,
        localCur,
        name,
        amountLocalCur,
        description,
        optStrg,
        optNmb,
        billType,
        penaltyAmount,
        payOrder,
        serviceNumber,
        billNumber,
        customerNumber,
        billMonth,
        billYear,
        billDate,
        billDueDate,
      ]);

  @override
  String toString() => 'Bill(serviceId: $serviceId, payItemId: $payItemId, '
      'billType: $billType, payOrder: $payOrder)';
}

/// A subscription payment item returned by `GET /v2/subscription`.
///
/// Looked up by either [serviceNumber] or [customerNumber]; the result set
/// contains all subscriptions found under the search criteria.
class Subscription implements PaymentItem {
  /// Creates a [Subscription].
  const Subscription({
    required this.serviceId,
    required this.merchant,
    required this.payItemId,
    required this.payItemDescr,
    required this.amountType,
    required this.localCur,
    required this.name,
    required this.amountLocalCur,
    required this.description,
    required this.optStrg,
    required this.optNmb,
    required this.serviceNumber,
    required this.customerReference,
    required this.customerName,
    required this.customerNumber,
    required this.startDate,
    required this.dueDate,
    required this.endDate,
  });

  /// Decodes from JSON.
  ///
  /// The wire key is `serviceid` (lowercase i, per the partner spec).
  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        serviceId: (json['serviceid'] as num).toInt(),
        merchant: json['merchant'] as String,
        payItemId: json['payItemId'] as String,
        payItemDescr: json['payItemDescr'] as String?,
        amountType: enumFromJson(
          AmountType.values,
          json['amountType'] as String?,
          fallback: AmountType.unknown,
        )!,
        localCur: json['localCur'] as String?,
        name: json['name'] as String?,
        amountLocalCur: (json['amountLocalCur'] as num?)?.toDouble(),
        description: json['description'] as String?,
        optStrg: json['optStrg'] as String?,
        optNmb: (json['optNmb'] as num?)?.toDouble(),
        serviceNumber: json['serviceNumber'] as String?,
        customerReference: json['customerReference'] as String?,
        customerName: json['customerName'] as String?,
        customerNumber: json['customerNumber'] as String?,
        startDate: LenientDate.parseOrNull(json['startDate'] as String?),
        dueDate: LenientDate.parseOrNull(json['dueDate'] as String?),
        endDate: LenientDate.parseOrNull(json['endDate'] as String?),
      );

  @override
  final int serviceId;

  @override
  final String merchant;

  @override
  final String payItemId;

  @override
  final String? payItemDescr;

  @override
  final AmountType amountType;

  @override
  final String? localCur;

  @override
  final String? name;

  @override
  final double? amountLocalCur;

  @override
  final String? description;

  @override
  final String? optStrg;

  @override
  final double? optNmb;

  /// Subscriber's service number (meter/account number).
  final String? serviceNumber;

  /// Merchant-assigned customer reference.
  final String? customerReference;

  /// Customer's display name.
  final String? customerName;

  /// Customer account number.
  final String? customerNumber;

  /// Date the subscription period starts.
  final DateTime? startDate;

  /// Payment due date for the current subscription period.
  final DateTime? dueDate;

  /// Date the subscription period ends.
  final DateTime? endDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription &&
          serviceId == other.serviceId &&
          merchant == other.merchant &&
          payItemId == other.payItemId &&
          payItemDescr == other.payItemDescr &&
          amountType == other.amountType &&
          localCur == other.localCur &&
          name == other.name &&
          amountLocalCur == other.amountLocalCur &&
          description == other.description &&
          optStrg == other.optStrg &&
          optNmb == other.optNmb &&
          serviceNumber == other.serviceNumber &&
          customerReference == other.customerReference &&
          customerName == other.customerName &&
          customerNumber == other.customerNumber &&
          startDate == other.startDate &&
          dueDate == other.dueDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hashAll([
        serviceId,
        merchant,
        payItemId,
        payItemDescr,
        amountType,
        localCur,
        name,
        amountLocalCur,
        description,
        optStrg,
        optNmb,
        serviceNumber,
        customerReference,
        customerName,
        customerNumber,
        startDate,
        dueDate,
        endDate,
      ]);

  @override
  String toString() =>
      'Subscription(serviceId: $serviceId, payItemId: $payItemId, '
      'serviceNumber: $serviceNumber)';
}

/// Request body for `POST /v2/quotestd`.
///
/// [amount] must be >= 1; [payItemId] must be non-empty. Both are validated
/// in the constructor and throw [SmobilpayConfigException] on violation.
class QuoteRequest {
  /// Creates a [QuoteRequest], validating [amount] and [payItemId].
  ///
  /// Throws [SmobilpayConfigException] if [amount] < 1 or [payItemId] is
  /// empty.
  QuoteRequest({
    required this.amount,
    required this.payItemId,
  }) {
    if (amount < 1) {
      throw SmobilpayConfigException(
        'amount must be >= 1, got $amount',
      );
    }
    if (payItemId.isEmpty) {
      throw const SmobilpayConfigException('payItemId must not be empty');
    }
  }

  /// Amount to be collected in the local currency of the payment item.
  ///
  /// Full integer, no decimals. Subject to the item's [AmountType].
  final int amount;

  /// Payment item identifier from the masterdata catalog to quote.
  final String payItemId;

  /// Encodes to JSON for the wire body.
  Map<String, dynamic> toJson() => {
        'amount': amount,
        'payItemId': payItemId,
      };

  @override
  String toString() => 'QuoteRequest(amount: $amount, payItemId: $payItemId)';
}

/// Quote response from `POST /v2/quotestd`.
///
/// The [quoteId] must be passed back on a collection request before
/// [expiresAt].
class QuoteResponse {
  /// Creates a [QuoteResponse].
  const QuoteResponse({
    required this.quoteId,
    required this.expiresAt,
    required this.payItemId,
    required this.amountLocalCur,
    required this.priceLocalCur,
    required this.priceSystemCur,
    required this.localCur,
    required this.systemCur,
    required this.promotion,
  });

  /// Decodes from JSON.
  factory QuoteResponse.fromJson(Map<String, dynamic> json) => QuoteResponse(
        quoteId: json['quoteId'] as String,
        expiresAt: LenientDate.parse(json['expiresAt'] as String),
        payItemId: json['payItemId'] as String,
        amountLocalCur: (json['amountLocalCur'] as num?)?.toDouble(),
        priceLocalCur: (json['priceLocalCur'] as num?)?.toDouble(),
        priceSystemCur: (json['priceSystemCur'] as num?)?.toDouble(),
        localCur: json['localCur'] as String?,
        systemCur: json['systemCur'] as String?,
        promotion: json['promotion'] as String?,
      );

  /// Unique quote identifier — pass this to the collection request.
  final String quoteId;

  /// UTC instant at which this quote expires.
  final DateTime expiresAt;

  /// Payment item identifier this quote applies to.
  final String payItemId;

  /// Quoted amount in local currency.
  final double? amountLocalCur;

  /// Quoted price in local currency (may include fees).
  final double? priceLocalCur;

  /// Quoted price in system currency.
  final double? priceSystemCur;

  /// Local currency (ISO 4217).
  final String? localCur;

  /// System currency (ISO 4217).
  final String? systemCur;

  /// Active promotion code applied to this quote, if any.
  final String? promotion;

  @override
  String toString() =>
      'QuoteResponse(quoteId: $quoteId, payItemId: $payItemId, '
      'expiresAt: $expiresAt)';
}

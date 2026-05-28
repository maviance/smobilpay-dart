import '../http/lenient_bool.dart';
import '../http/lenient_num.dart';
import '../http/query_params.dart';
import '../http/transport.dart';
import '../model/enums.dart';
import '../model/i18n_text.dart';
import '../model/payment_item.dart';

/// Static reference-data endpoints. Backed by the `Masterdata` spec tag.
///
/// These endpoints return catalog objects that change infrequently and are
/// safe to cache between sessions.
class MasterdataApi {
  /// Creates a [MasterdataApi].
  MasterdataApi(this._transport);

  final HttpTransport _transport;

  /// `GET /v2/merchant` — all merchants in the system.
  Future<List<Merchant>> merchants() async {
    final json = await _transport.getJson('/v2/merchant', QueryParams())
        as List<dynamic>;
    return json
        .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /v2/service` — all services in the system.
  Future<List<Service>> services() async {
    final json =
        await _transport.getJson('/v2/service', QueryParams()) as List<dynamic>;
    return json
        .map((e) => Service.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /v2/product[?serviceid=]` — purchasable products.
  ///
  /// When [serviceId] is provided only items for that service are returned.
  Future<List<Product>> products({int? serviceId}) async {
    final json = await _transport.getJson(
      '/v2/product',
      QueryParams()..add('serviceid', serviceId),
    ) as List<dynamic>;
    return json
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /v2/voucher[?serviceid=]` — purchasable vouchers.
  ///
  /// The wire shape is identical to [Product]; the digital pin is delivered
  /// on `CollectionResponse.pin` after a successful collection.
  /// When [serviceId] is provided only items for that service are returned.
  Future<List<Product>> vouchers({int? serviceId}) async {
    final json = await _transport.getJson(
      '/v2/voucher',
      QueryParams()..add('serviceid', serviceId),
    ) as List<dynamic>;
    return json
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /v2/topup[?serviceid=]` — top-up packages.
  ///
  /// When [serviceId] is provided only items for that service are returned.
  Future<List<Topup>> topups({int? serviceId}) async {
    final json = await _transport.getJson(
      '/v2/topup',
      QueryParams()..add('serviceid', serviceId),
    ) as List<dynamic>;
    return json.map((e) => Topup.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /v2/cashin[?serviceid=]` — cash-in (disbursement) items.
  ///
  /// When [serviceId] is provided only items for that service are returned.
  Future<List<Cashin>> cashins({int? serviceId}) async {
    final json = await _transport.getJson(
      '/v2/cashin',
      QueryParams()..add('serviceid', serviceId),
    ) as List<dynamic>;
    return json.map((e) => Cashin.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /v2/cashout[?serviceid=]` — cash-out (collection) items.
  ///
  /// When [serviceId] is provided only items for that service are returned.
  Future<List<Cashout>> cashouts({int? serviceId}) async {
    final json = await _transport.getJson(
      '/v2/cashout',
      QueryParams()..add('serviceid', serviceId),
    ) as List<dynamic>;
    return json
        .map((e) => Cashout.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// A merchant supported by the system.
///
/// Every [Service] is assigned to exactly one merchant.
class Merchant {
  /// Creates a [Merchant].
  const Merchant({
    required this.merchant,
    required this.name,
    required this.description,
    required this.country,
    required this.status,
    required this.logo,
    required this.logoHash,
  });

  /// Decodes from JSON.
  factory Merchant.fromJson(Map<String, dynamic> json) => Merchant(
        merchant: json['merchant'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        country: json['country'] as String,
        status: enumFromJson(
          MerchantStatus.values,
          json['status'] as String?,
          fallback: MerchantStatus.unknown,
        )!,
        logo: json['logo'] as String?,
        logoHash: json['logoHash'] as String?,
      );

  /// Unique merchant code.
  final String merchant;

  /// Human-readable merchant name.
  final String name;

  /// Merchant description.
  final String? description;

  /// ISO 3166-1 alpha-3 country code.
  final String country;

  /// Merchant availability status.
  final MerchantStatus status;

  /// URL of the merchant logo, or `null` if none.
  final String? logo;

  /// MD5 hash of the logo; changes when the logo is updated.
  final String? logoHash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Merchant &&
          merchant == other.merchant &&
          name == other.name &&
          description == other.description &&
          country == other.country &&
          status == other.status &&
          logo == other.logo &&
          logoHash == other.logoHash;

  @override
  int get hashCode => Object.hash(
        merchant,
        name,
        description,
        country,
        status,
        logo,
        logoHash,
      );

  /// Encodes this [Merchant] as a JSON map.
  Map<String, dynamic> toJson() => {
        'country': country,
        'description': description,
        'logo': logo,
        'logoHash': logoHash,
        'merchant': merchant,
        'name': name,
        'status': status.wireName,
      };

  @override
  String toString() =>
      'Merchant(merchant: $merchant, name: $name, status: $status)';
}

/// A service offered by a merchant.
///
/// The `isReq*` flags indicate which fields a collection request must include.
/// [type] determines which masterdata endpoint produces the matching payment
/// items for this service.
class Service {
  /// Creates a [Service].
  const Service({
    required this.serviceId,
    required this.merchant,
    required this.title,
    required this.description,
    required this.category,
    required this.country,
    required this.localCur,
    required this.type,
    required this.status,
    required this.isReqCustomerName,
    required this.isReqCustomerAddress,
    required this.isReqCustomerNumber,
    required this.isReqServiceNumber,
    required this.isVerifiable,
    required this.labelCustomerNumber,
    required this.labelServiceNumber,
    required this.hint,
    required this.validationMask,
    required this.denomination,
  });

  /// Decodes from JSON.
  ///
  /// The wire key is `serviceid` (lowercase i, per the partner spec).
  factory Service.fromJson(Map<String, dynamic> json) => Service(
        serviceId: LenientNum.asInt(json['serviceid']),
        merchant: json['merchant'] as String?,
        title: json['title'] as String?,
        description: json['description'] as String?,
        category: json['category'] as String?,
        country: json['country'] as String?,
        localCur: json['localCur'] as String?,
        type: enumFromJson(
          ServiceType.values,
          json['type'] as String?,
          fallback: ServiceType.unknown,
        )!,
        status: enumFromJson(
          ServiceStatus.values,
          json['status'] as String?,
          fallback: ServiceStatus.unknown,
        )!,
        isReqCustomerName: LenientBool.asBool(json['isReqCustomerName']),
        isReqCustomerAddress: LenientBool.asBool(json['isReqCustomerAddress']),
        isReqCustomerNumber: LenientBool.asBool(json['isReqCustomerNumber']),
        isReqServiceNumber: LenientBool.asBool(json['isReqServiceNumber']),
        isVerifiable: LenientBool.asBool(json['isVerifiable']),
        labelCustomerNumber:
            ((json['labelCustomerNumber'] as List<dynamic>?) ?? const [])
                .map((e) => I18nText.fromJson(e as Map<String, dynamic>))
                .toList(),
        labelServiceNumber:
            ((json['labelServiceNumber'] as List<dynamic>?) ?? const [])
                .map((e) => I18nText.fromJson(e as Map<String, dynamic>))
                .toList(),
        hint: ((json['hint'] as List<dynamic>?) ?? const [])
            .map((e) => I18nText.fromJson(e as Map<String, dynamic>))
            .toList(),
        validationMask: json['validationMask'] as String?,
        denomination: LenientNum.asIntOrNull(json['denomination']),
      );

  /// Unique service identifier.
  final int serviceId;

  /// Code of the merchant that owns this service. Nullable: the live
  /// catalog occasionally surfaces sparse rows where this is absent.
  final String? merchant;

  /// Service display title.
  final String? title;

  /// Service description.
  final String? description;

  /// Service category label.
  final String? category;

  /// ISO 3166-1 alpha-3 country code.
  final String? country;

  /// ISO 4217 local currency code.
  final String? localCur;

  /// Service type, drives which masterdata endpoint to query.
  final ServiceType type;

  /// Operational status of this service.
  final ServiceStatus status;

  /// Whether the customer's name is required in the collection request.
  final bool isReqCustomerName;

  /// Whether the customer's address is required in the collection request.
  final bool isReqCustomerAddress;

  /// Whether a customer number is required in the collection request.
  final bool isReqCustomerNumber;

  /// Whether a service number is required in the collection request.
  final bool isReqServiceNumber;

  /// Whether this service supports account verification before collection.
  final bool isVerifiable;

  /// Localized labels for the customer number field.
  final List<I18nText> labelCustomerNumber;

  /// Localized labels for the service number field.
  final List<I18nText> labelServiceNumber;

  /// Localized hint texts shown to the end user.
  final List<I18nText> hint;

  /// Regular expression mask for validating the service number.
  final String? validationMask;

  /// Fixed denomination, if applicable.
  final int? denomination;

  /// Encodes this [Service] as a JSON map.
  Map<String, dynamic> toJson() => {
        'category': category,
        'country': country,
        'denomination': denomination,
        'description': description,
        'hint': hint.map((e) => e.toJson()).toList(),
        'isReqCustomerAddress': isReqCustomerAddress,
        'isReqCustomerName': isReqCustomerName,
        'isReqCustomerNumber': isReqCustomerNumber,
        'isReqServiceNumber': isReqServiceNumber,
        'isVerifiable': isVerifiable,
        'labelCustomerNumber':
            labelCustomerNumber.map((e) => e.toJson()).toList(),
        'labelServiceNumber':
            labelServiceNumber.map((e) => e.toJson()).toList(),
        'localCur': localCur,
        'merchant': merchant,
        'serviceid': serviceId,
        'status': status.wireName,
        'title': title,
        'type': type.wireName,
        'validationMask': validationMask,
      };
}

/// A cash-out item — collection from a customer's mobile wallet.
///
/// Money flows out of the customer's wallet into the partner's balance.
/// Returned by `GET /v2/cashout`.
class Cashout implements PaymentItem {
  /// Creates a [Cashout].
  const Cashout({
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
  });

  /// Decodes from JSON.
  factory Cashout.fromJson(Map<String, dynamic> json) => Cashout(
        serviceId: LenientNum.asInt(json['serviceid']),
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
        amountLocalCur: LenientNum.asDoubleOrNull(json['amountLocalCur']),
        description: json['description'] as String?,
        optStrg: json['optStrg'] as String?,
        optNmb: LenientNum.asDoubleOrNull(json['optNmb']),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cashout &&
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
          optNmb == other.optNmb;

  @override
  int get hashCode => Object.hash(
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
      );

  /// Encodes this [Cashout] as a JSON map.
  Map<String, dynamic> toJson() => {
        'amountLocalCur': amountLocalCur,
        'amountType': amountType.wireName,
        'description': description,
        'localCur': localCur,
        'merchant': merchant,
        'name': name,
        'optNmb': optNmb,
        'optStrg': optStrg,
        'payItemDescr': payItemDescr,
        'payItemId': payItemId,
        'serviceid': serviceId,
      };

  @override
  String toString() => 'Cashout(serviceId: $serviceId, payItemId: $payItemId, '
      'amountType: $amountType)';
}

/// A cash-in item — disbursement into a recipient's mobile wallet.
///
/// Money flows into the recipient's wallet from the partner's balance.
/// Returned by `GET /v2/cashin`.
class Cashin implements PaymentItem {
  /// Creates a [Cashin].
  const Cashin({
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
  });

  /// Decodes from JSON.
  factory Cashin.fromJson(Map<String, dynamic> json) => Cashin(
        serviceId: LenientNum.asInt(json['serviceid']),
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
        amountLocalCur: LenientNum.asDoubleOrNull(json['amountLocalCur']),
        description: json['description'] as String?,
        optStrg: json['optStrg'] as String?,
        optNmb: LenientNum.asDoubleOrNull(json['optNmb']),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cashin &&
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
          optNmb == other.optNmb;

  @override
  int get hashCode => Object.hash(
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
      );

  /// Encodes this [Cashin] as a JSON map.
  Map<String, dynamic> toJson() => {
        'amountLocalCur': amountLocalCur,
        'amountType': amountType.wireName,
        'description': description,
        'localCur': localCur,
        'merchant': merchant,
        'name': name,
        'optNmb': optNmb,
        'optStrg': optStrg,
        'payItemDescr': payItemDescr,
        'payItemId': payItemId,
        'serviceid': serviceId,
      };

  @override
  String toString() => 'Cashin(serviceId: $serviceId, payItemId: $payItemId, '
      'amountType: $amountType)';
}

/// A top-up package. Returned by `GET /v2/topup`.
class Topup implements PaymentItem {
  /// Creates a [Topup].
  const Topup({
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
  });

  /// Decodes from JSON.
  factory Topup.fromJson(Map<String, dynamic> json) => Topup(
        serviceId: LenientNum.asInt(json['serviceid']),
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
        amountLocalCur: LenientNum.asDoubleOrNull(json['amountLocalCur']),
        description: json['description'] as String?,
        optStrg: json['optStrg'] as String?,
        optNmb: LenientNum.asDoubleOrNull(json['optNmb']),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Topup &&
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
          optNmb == other.optNmb;

  @override
  int get hashCode => Object.hash(
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
      );

  /// Encodes this [Topup] as a JSON map.
  Map<String, dynamic> toJson() => {
        'amountLocalCur': amountLocalCur,
        'amountType': amountType.wireName,
        'description': description,
        'localCur': localCur,
        'merchant': merchant,
        'name': name,
        'optNmb': optNmb,
        'optStrg': optStrg,
        'payItemDescr': payItemDescr,
        'payItemId': payItemId,
        'serviceid': serviceId,
      };

  @override
  String toString() => 'Topup(serviceId: $serviceId, payItemId: $payItemId, '
      'amountType: $amountType)';
}

/// A purchasable product or voucher.
///
/// Returned by `GET /v2/product` and `GET /v2/voucher`. For voucher
/// purchases, the digital code is delivered on `CollectionResponse.pin`
/// after a successful collection.
class Product implements PaymentItem {
  /// Creates a [Product].
  const Product({
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
  });

  /// Decodes from JSON.
  factory Product.fromJson(Map<String, dynamic> json) => Product(
        serviceId: LenientNum.asInt(json['serviceid']),
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
        amountLocalCur: LenientNum.asDoubleOrNull(json['amountLocalCur']),
        description: json['description'] as String?,
        optStrg: json['optStrg'] as String?,
        optNmb: LenientNum.asDoubleOrNull(json['optNmb']),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
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
          optNmb == other.optNmb;

  @override
  int get hashCode => Object.hash(
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
      );

  /// Encodes this [Product] as a JSON map.
  Map<String, dynamic> toJson() => {
        'amountLocalCur': amountLocalCur,
        'amountType': amountType.wireName,
        'description': description,
        'localCur': localCur,
        'merchant': merchant,
        'name': name,
        'optNmb': optNmb,
        'optStrg': optStrg,
        'payItemDescr': payItemDescr,
        'payItemId': payItemId,
        'serviceid': serviceId,
      };

  @override
  String toString() => 'Product(serviceId: $serviceId, payItemId: $payItemId, '
      'amountType: $amountType)';
}

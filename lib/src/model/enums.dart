/// Service classification. Drives which masterdata endpoint produces the
/// matching payment items for a given service.
enum ServiceType {
  /// Bills are looked up via `GET /v2/bill?serviceNumber=...` and may return
  /// multiple open bills.
  searchableBill('SEARCHABLE_BILL'),

  /// Bills are looked up but always return a single bill.
  nonSearchableBill('NON_SEARCHABLE_BILL'),

  /// Returned by `GET /v2/product`.
  product('PRODUCT'),

  /// Returned by `GET /v2/topup`.
  topup('TOPUP'),

  /// Returned by `GET /v2/subscription`.
  subscription('SUBSCRIPTION'),

  /// Disbursement — money flows into recipient wallet.
  cashin('CASHIN'),

  /// Collection — money flows out of customer wallet.
  cashout('CASHOUT'),

  /// Vouchers — returned by `GET /v2/voucher`.
  voucher('VOUCHER'),

  /// Forward-compatibility fallback for values not enumerated above.
  unknown('UNKNOWN');

  /// Creates a [ServiceType].
  const ServiceType(this.wireName);

  /// Wire name as emitted by the partner API.
  final String wireName;
}

/// How the amount is determined for a payment item.
enum AmountType {
  /// Must be paid in full at `amountLocalCur`.
  fixed('FIXED'),

  /// Caller chooses the amount.
  custom('CUSTOM'),

  /// Amount may be less than `amountLocalCur`.
  partial('PARTIAL'),

  /// Amount may exceed `amountLocalCur` (subject to country regulation).
  overpay('OVERPAY'),

  /// Forward-compatibility fallback.
  unknown('UNKNOWN');

  /// Creates an [AmountType].
  const AmountType(this.wireName);

  /// Wire name as emitted by the partner API.
  final String wireName;
}

/// Classification of a [Bill].
enum BillType {
  /// Regular open bill.
  regular('REGULAR'),

  /// Past-due bill.
  overdue('OVERDUE'),

  /// Forward-compatibility fallback.
  unknown('UNKNOWN');

  /// Creates a [BillType].
  const BillType(this.wireName);

  /// Wire name as emitted by the partner API.
  final String wireName;
}

/// Availability status of a merchant.
enum MerchantStatus {
  /// Operational.
  active('Active'),

  /// Disabled.
  inactive('Inactive'),

  /// Forward-compatibility fallback.
  unknown('Unknown');

  /// Creates a [MerchantStatus].
  const MerchantStatus(this.wireName);

  /// Wire name as emitted by the partner API.
  final String wireName;
}

/// Availability status of a service.
enum ServiceStatus {
  /// Operational.
  active('Active'),

  /// Disabled.
  inactive('Inactive'),

  /// Forward-compatibility fallback.
  unknown('Unknown');

  /// Creates a [ServiceStatus].
  const ServiceStatus(this.wireName);

  /// Wire name as emitted by the partner API.
  final String wireName;
}

/// Payment processing status.
enum PaymentStatusType {
  /// Reversed by a chargeback / refund.
  reversed('REVERSED'),

  /// Awaiting clearing.
  pending('PENDING'),

  /// Failed.
  errored('ERRORED'),

  /// Settled.
  success('SUCCESS'),

  /// Forward-compatibility fallback.
  unknown('UNKNOWN');

  /// Creates a [PaymentStatusType].
  const PaymentStatusType(this.wireName);

  /// Wire name as emitted by the partner API.
  final String wireName;
}

/// Account-recognition outcome from `GET /v2/validate`.
enum CustomerAccountStatus {
  /// Account authenticity could be neither verified nor validated.
  unknown('UNKNOWN'),

  /// Account syntax has been internally confirmed.
  validated('VALIDATED'),

  /// Account has been positively cross-checked against the service provider.
  verified('VERIFIED');

  /// Creates a [CustomerAccountStatus].
  const CustomerAccountStatus(this.wireName);

  /// Wire name as emitted by the partner API.
  final String wireName;
}

/// Decodes [json] into one of [values] by matching `wireName`.
///
/// Returns [fallback] (or `null`) when [json] is null or unrecognised.
T? enumFromJson<T extends Enum>(
  List<T> values,
  String? json, {
  T? fallback,
}) {
  if (json == null) return fallback;
  for (final v in values) {
    // ignore: avoid_dynamic_calls
    final wire = (v as dynamic).wireName as String;
    if (wire == json) return v;
  }
  return fallback;
}

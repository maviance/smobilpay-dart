import 'enums.dart';

/// Common interface for the payment-item DTOs returned by the masterdata
/// endpoints (`/v2/product`, `/v2/voucher`, `/v2/topup`, `/v2/cashin`,
/// `/v2/cashout`) and the lookup endpoints (`/v2/bill`,
/// `/v2/subscription`).
///
/// [payItemId] is the value passed to `QuoteRequest` to request pricing
/// for this item.
abstract interface class PaymentItem {
  /// Identifier of the service this item belongs to.
  int get serviceId;

  /// Merchant code that owns the service.
  String get merchant;

  /// Identifier passed to `/v2/quotestd` to request a price quote.
  String get payItemId;

  /// Human-readable item description.
  String? get payItemDescr;

  /// How the amount is determined for this item.
  AmountType get amountType;

  /// ISO 4217 local currency.
  String? get localCur;

  /// Display name.
  String? get name;

  /// Catalog price in the local currency, or null for CUSTOM-amount items.
  double? get amountLocalCur;

  /// Free-form description.
  String? get description;

  /// Optional string slot used by some services.
  String? get optStrg;

  /// Optional numeric slot used by some services.
  double? get optNmb;
}

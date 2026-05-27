/// Commission earned on a transaction. Present on `PaymentStatus.commission`
/// only when the commission feature is enabled for the merchant/service.
class Commission {
  /// Creates a [Commission].
  const Commission({required this.earnings, required this.currency});

  /// Decodes from JSON.
  factory Commission.fromJson(Map<String, dynamic> json) => Commission(
        earnings: (json['earnings'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
      );

  /// Commission amount earned.
  final double? earnings;

  /// Currency (ISO 4217).
  final String? currency;

  /// Encodes to JSON.
  Map<String, dynamic> toJson() => {'earnings': earnings, 'currency': currency};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Commission &&
          earnings == other.earnings &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(earnings, currency);

  @override
  String toString() => 'Commission(earnings: $earnings, currency: $currency)';
}

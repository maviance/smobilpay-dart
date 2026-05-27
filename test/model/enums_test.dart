import 'package:smobilpay/src/model/enums.dart';
import 'package:test/test.dart';

void main() {
  group('enumFromJson', () {
    test('parses by wire name (case-sensitive when possible)', () {
      expect(enumFromJson(ServiceType.values, 'SEARCHABLE_BILL'),
          ServiceType.searchableBill);
      expect(enumFromJson(ServiceType.values, 'TOPUP'), ServiceType.topup);
      expect(enumFromJson(AmountType.values, 'FIXED'), AmountType.fixed);
      expect(
          enumFromJson(MerchantStatus.values, 'Active'), MerchantStatus.active);
    });

    test('returns fallback for unknown', () {
      expect(
        enumFromJson(ServiceType.values, 'NOT_A_TYPE',
            fallback: ServiceType.unknown),
        ServiceType.unknown,
      );
    });

    test('returns null when no fallback and input is unknown', () {
      expect(enumFromJson(AmountType.values, 'NOT_A_TYPE'), isNull);
    });

    test('returns null for null input when no fallback', () {
      expect(enumFromJson(AmountType.values, null), isNull);
    });

    test('CustomerAccountStatus parses the three documented values', () {
      expect(enumFromJson(CustomerAccountStatus.values, 'UNKNOWN'),
          CustomerAccountStatus.unknown);
      expect(enumFromJson(CustomerAccountStatus.values, 'VALIDATED'),
          CustomerAccountStatus.validated);
      expect(enumFromJson(CustomerAccountStatus.values, 'VERIFIED'),
          CustomerAccountStatus.verified);
    });
  });

  test('every enum has a wireName matching the spec', () {
    expect(ServiceType.searchableBill.wireName, 'SEARCHABLE_BILL');
    expect(ServiceType.nonSearchableBill.wireName, 'NON_SEARCHABLE_BILL');
    expect(AmountType.overpay.wireName, 'OVERPAY');
    expect(MerchantStatus.inactive.wireName, 'Inactive');
    expect(ServiceStatus.active.wireName, 'Active');
    expect(BillType.regular.wireName, 'REGULAR');
    expect(PaymentStatusType.success.wireName, 'SUCCESS');
    expect(CustomerAccountStatus.verified.wireName, 'VERIFIED');
  });
}

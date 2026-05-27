import 'package:smobilpay/src/model/commission.dart';
import 'package:smobilpay/src/model/i18n_text.dart';
import 'package:test/test.dart';

void main() {
  group('I18nText', () {
    test('round-trips JSON', () {
      const t = I18nText(language: 'en', localText: 'Service Number');
      expect(I18nText.fromJson(t.toJson()), t);
    });

    test('equality by value', () {
      const a = I18nText(language: 'fr', localText: 'numéro');
      const b = I18nText(language: 'fr', localText: 'numéro');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Commission', () {
    test('round-trips JSON', () {
      const c = Commission(earnings: 2.5, currency: 'XAF');
      expect(Commission.fromJson(c.toJson()), c);
    });

    test('accepts null fields', () {
      final c = Commission.fromJson({});
      expect(c.earnings, isNull);
      expect(c.currency, isNull);
    });
  });
}

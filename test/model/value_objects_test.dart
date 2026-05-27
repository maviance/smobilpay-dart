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

    test('equality by value', () {
      const a = Commission(earnings: 1.0, currency: 'XAF');
      const b = Commission(earnings: 1.0, currency: 'XAF');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('inequality on different value', () {
      const a = Commission(earnings: 1.0, currency: 'XAF');
      const b = Commission(earnings: 2.0, currency: 'XAF');
      expect(a, isNot(equals(b)));
    });

    test('toString contains fields', () {
      const c = Commission(earnings: 5.0, currency: 'XAF');
      expect(c.toString(), contains('5.0'));
      expect(c.toString(), contains('XAF'));
    });
  });

  group('I18nText extra', () {
    test('toString contains language and text', () {
      const t = I18nText(language: 'fr', localText: 'Numero');
      expect(t.toString(), contains('fr'));
      expect(t.toString(), contains('Numero'));
    });

    test('inequality on different language', () {
      const a = I18nText(language: 'en', localText: 'Number');
      const b = I18nText(language: 'fr', localText: 'Number');
      expect(a, isNot(equals(b)));
    });
  });
}

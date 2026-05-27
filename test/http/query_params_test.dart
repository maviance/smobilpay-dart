import 'package:smobilpay/src/http/query_params.dart';
import 'package:test/test.dart';

void main() {
  group('QueryParams', () {
    test('empty builder produces empty query', () {
      expect(QueryParams().toQuery(), '');
      expect(QueryParams().isEmpty, isTrue);
    });

    test('adds params in insertion order', () {
      final q = QueryParams()
        ..add('a', 'one')
        ..add('b', 'two');
      expect(q.toQuery(), 'a=one&b=two');
    });

    test('skips null', () {
      final q = QueryParams()
        ..add('present', 'yes')
        ..add('missing', null);
      expect(q.toQuery(), 'present=yes');
    });

    test('skips empty string', () {
      final q = QueryParams()
        ..add('present', 'yes')
        ..add('empty', '');
      expect(q.toQuery(), 'present=yes');
    });

    test('percent-encodes spaces', () {
      final q = QueryParams()..add('q', 'hello world');
      expect(q.toQuery(), 'q=hello%20world');
    });

    test('stringifies int / double / bool', () {
      final q = QueryParams()
        ..add('i', 42)
        ..add('d', 1.5)
        ..add('b', true);
      expect(q.toQuery(), 'i=42&d=1.5&b=true');
    });

    test('formats DateTime as ISO instant with Z', () {
      final q = QueryParams()..add('ts', DateTime.utc(2026, 1, 31, 12));
      expect(q.toQuery(), 'ts=2026-01-31T12%3A00%3A00.000Z');
    });

    test('throws ArgumentError on empty name', () {
      expect(() => QueryParams().add('', 'x'), throwsA(isA<ArgumentError>()));
    });
  });
}

import 'lenient_date.dart';

/// Fluent builder for URL-encoded query strings.
///
/// Skips `null` and empty-string values so optional parameters can be
/// added unconditionally. Insertion order is preserved.
class QueryParams {
  /// Creates an empty builder.
  QueryParams();

  final List<_Entry> _entries = [];

  /// Adds a parameter unless [value] is `null` or an empty string.
  void add(String name, Object? value) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (value == null) return;
    final s = switch (value) {
      final String x => x,
      final DateTime dt => LenientDate.formatInstant(dt),
      _ => value.toString(),
    };
    if (s.isEmpty) return;
    _entries.add(_Entry(name, s));
  }

  /// True when no parameters have been added (after null/empty filter).
  bool get isEmpty => _entries.isEmpty;

  /// Renders the parameters as a URL-encoded query string (no leading `?`).
  String toQuery() {
    if (_entries.isEmpty) return '';
    return _entries.map((e) {
      final name = Uri.encodeQueryComponent(e.name).replaceAll('+', '%20');
      final value = Uri.encodeQueryComponent(e.value).replaceAll('+', '%20');
      return '$name=$value';
    }).join('&');
  }
}

class _Entry {
  const _Entry(this.name, this.value);

  final String name;
  final String value;
}

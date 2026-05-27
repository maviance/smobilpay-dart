/// Parses and formats every date/datetime shape the partner API emits.
///
/// Accepts ISO date, instant (`Z`), offset datetime, and local datetime.
class LenientDate {
  const LenientDate._();

  /// Parses [input] into a UTC [DateTime].
  static DateTime parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Empty date string', input);
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      final parts = trimmed.split('-').map(int.parse).toList();
      return DateTime.utc(parts[0], parts[1], parts[2]);
    }
    final hasOffset = RegExp(r'[Zz]$|[+-]\d{2}:?\d{2}$').hasMatch(trimmed);
    final canonical = hasOffset ? trimmed : '${trimmed}Z';
    final dt = DateTime.tryParse(canonical);
    if (dt == null) {
      throw FormatException('Not a valid ISO-8601 date/datetime', input);
    }
    return dt.toUtc();
  }

  /// Like [parse], but returns `null` for `null` or empty input.
  static DateTime? parseOrNull(String? input) {
    if (input == null || input.isEmpty) return null;
    return parse(input);
  }

  /// Formats [dt] as a UTC instant with `Z` suffix.
  static String formatInstant(DateTime dt) {
    final iso = dt.toUtc().toIso8601String();
    if (iso.endsWith('Z')) return iso;
    return iso.replaceFirst(RegExp(r'[+-]\d{2}:\d{2}$'), 'Z');
  }
}

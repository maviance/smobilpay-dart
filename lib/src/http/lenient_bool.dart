/// Lenient boolean decoder that accepts `bool`, `num` (`0`→false, non-zero→true),
/// and `String` (`"true"`/`"1"` → true, `"false"`/`"0"` → false).
///
/// The partner API occasionally emits boolean fields as `0`/`1` integers
/// or as `"true"`/`"false"` strings; this helper accepts every variant
/// the wire emits.
class LenientBool {
  const LenientBool._();

  /// Required bool. Throws [FormatException] on null or unrecognised value.
  static bool asBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final lower = v.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0' || lower.isEmpty) return false;
    }
    throw FormatException('expected bool, got $v (${v?.runtimeType})');
  }

  /// Optional bool. Null/empty → null, otherwise delegates to [asBool].
  static bool? asBoolOrNull(Object? v) {
    if (v == null) return null;
    if (v is String && v.isEmpty) return null;
    return asBool(v);
  }
}

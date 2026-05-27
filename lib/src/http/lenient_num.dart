/// Lenient numeric decoders that accept both `num` and `String` JSON values.
///
/// The S3P partner API occasionally emits numeric fields as JSON strings
/// (e.g. `"20053"` instead of `20053`). Java's Jackson coerces these
/// automatically; we mirror that here.
class LenientNum {
  const LenientNum._();

  /// Required int. Throws [FormatException] on null or unrepresentable.
  static int asInt(Object? v) {
    final n = _toNum(v);
    if (n == null) {
      throw const FormatException('expected int, got null');
    }
    return n.toInt();
  }

  /// Optional int. Null/empty → null.
  static int? asIntOrNull(Object? v) => _toNum(v)?.toInt();

  /// Required double. Throws on null.
  static double asDouble(Object? v) {
    final n = _toNum(v);
    if (n == null) {
      throw const FormatException('expected double, got null');
    }
    return n.toDouble();
  }

  /// Optional double. Null/empty → null.
  static double? asDoubleOrNull(Object? v) => _toNum(v)?.toDouble();

  static num? _toNum(Object? v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) {
      if (v.isEmpty) return null;
      return num.parse(v);
    }
    return null;
  }
}

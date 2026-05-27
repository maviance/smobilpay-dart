import 'dart:io';

/// Diffs normalized smoke-test logs between Dart and any other client
/// (Java/Go/PHP/Node).
///
/// Usage: `dart run tool/compare_smoketest.dart --dart out/dart.log --other out/java.log`
Future<void> main(List<String> args) async {
  String? dartPath;
  String? otherPath;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--dart':
        dartPath = args[++i];
      case '--other':
        otherPath = args[++i];
      default:
        stderr.writeln('Unknown arg: ${args[i]}');
        exit(2);
    }
  }
  if (dartPath == null || otherPath == null) {
    stderr.writeln('Usage: compare_smoketest --dart <path> --other <path>');
    exit(2);
  }
  final a = _normalize(File(dartPath).readAsLinesSync());
  final b = _normalize(File(otherPath).readAsLinesSync());
  if (_equal(a, b)) {
    stdout.writeln('OK: logs match after normalization (${a.length} lines)');
    exit(0);
  }
  for (var i = 0; i < a.length || i < b.length; i++) {
    final left = i < a.length ? a[i] : '';
    final right = i < b.length ? b[i] : '';
    if (left != right) {
      stdout.writeln('- ${left.isEmpty ? "<eof>" : left}');
      stdout.writeln('+ ${right.isEmpty ? "<eof>" : right}');
    }
  }
  exit(1);
}

List<String> _normalize(List<String> lines) {
  return lines.map((line) {
    var s = line.trimRight();
    s = s.replaceAll(
        RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z'), '<ts>');
    s = s.replaceAll(
        RegExp(
            r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'),
        '<id>');
    s = s.replaceAll(RegExp(r'\bPTN-[A-Z0-9-]+'), 'PTN-<id>');
    s = s.replaceAll(RegExp(r'\bTRID-[A-Z0-9-]+'), 'TRID-<id>');
    s = s.replaceAll(RegExp(r'(prefix:\s*)[A-Za-z0-9._-]+'), r'\1<token>');
    return s;
  }).toList();
}

bool _equal(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

import 'dart:io';

/// Reads `coverage/lcov.info` and exits non-zero if line coverage on
/// `lib/src/` is below the target percentage.
///
/// Usage: `dart run tool/check_coverage.dart <lcov-path> <min-percent>`
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Usage: check_coverage <lcov-path> <min-percent>');
    exit(2);
  }
  final lcovPath = args[0];
  final target = double.parse(args[1]);

  final lines = await File(lcovPath).readAsLines();
  var hit = 0;
  var found = 0;
  var keep = false;
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      keep = line.contains('/lib/src/') || line.startsWith('SF:lib/src/');
    } else if (keep && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    } else if (keep && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    }
  }
  if (found == 0) {
    stderr.writeln('No lines found in lib/src/ coverage. Did the test run?');
    exit(2);
  }
  final pct = (hit / found) * 100;
  stdout.writeln('Coverage on lib/src/: ${pct.toStringAsFixed(1)}% '
      '($hit / $found lines). Target: $target%.');
  if (pct + 0.05 < target) {
    stderr.writeln('FAIL: coverage below target');
    exit(1);
  }
  stdout.writeln('PASS');
}

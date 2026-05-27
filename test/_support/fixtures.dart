import 'dart:convert';
import 'dart:io';

/// Loads `test/fixtures/<name>.json` and returns the decoded value.
Object loadFixture(String name) {
  final file = File('test/fixtures/$name.json');
  if (!file.existsSync()) {
    throw StateError('fixture not found: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Object;
}

/// Convenience: load as `Map<String, dynamic>`.
Map<String, dynamic> loadFixtureMap(String name) =>
    loadFixture(name) as Map<String, dynamic>;

/// Convenience: load as `List<dynamic>`.
List<dynamic> loadFixtureList(String name) =>
    loadFixture(name) as List<dynamic>;

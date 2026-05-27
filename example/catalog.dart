// ignore_for_file: avoid_print

// Catalog discovery: list merchants and services available to the partner.
//
// Usage: same env vars as ping.dart, then:
//   dart run example/catalog.dart

import 'dart:io';
import 'package:smobilpay/smobilpay.dart';

Future<void> main() async {
  final client = SmobilpayClient(
    config: SmobilpayConfig(
      baseUrl: Uri.parse(Platform.environment['SMOBILPAY_BASE_URL']!),
      publicKey: Platform.environment['SMOBILPAY_PUBLIC_KEY']!,
      secretKey: Platform.environment['SMOBILPAY_SECRET_KEY']!,
    ),
  );
  try {
    final merchants = await client.masterdata.merchants();
    print('Merchants: ${merchants.length}');
    for (final m in merchants.take(5)) {
      print('  ${m.merchant}: ${m.name} (${m.country}, ${m.status})');
    }

    final services = await client.masterdata.services();
    print('\nServices: ${services.length}');
    final byType = <ServiceType, int>{};
    for (final s in services) {
      byType[s.type] = (byType[s.type] ?? 0) + 1;
    }
    final sortedTypes = byType.keys.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final t in sortedTypes) {
      print('  ${t.name}: ${byType[t]}');
    }
  } finally {
    client.close();
  }
}

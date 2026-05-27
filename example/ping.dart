// ignore_for_file: avoid_print

// Smallest possible runnable: mint a token, ping, print the version.
//
// Usage:
//   export SMOBILPAY_BASE_URL=https://api.example.invalid
//   export SMOBILPAY_PUBLIC_KEY=...
//   export SMOBILPAY_SECRET_KEY=...
//   dart run example/ping.dart

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
    final pong = await client.verify.ping();
    print('Server time:    ${pong.time}');
    print('Server version: ${pong.version}');
    print('Public key:     ${pong.key}');
  } finally {
    client.close();
  }
}

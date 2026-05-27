// ignore_for_file: avoid_print

// Pre-payment account validation: verify a serviceNumber syntactically
// (verifyServiceNumber, available on services where isVerifiable=true) and
// validate a destination against the upstream provider (validateAccount,
// restricted endpoint — partners need compliance clearance).
//
// Usage:
//   export SMOBILPAY_BASE_URL=https://api.example.invalid
//   export SMOBILPAY_PUBLIC_KEY=...
//   export SMOBILPAY_SECRET_KEY=...
//   dart run example/account_validation.dart

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
    // Verify a serviceNumber (cheap, available on isVerifiable services).
    try {
      final valid = await client.accountValidation.verifyServiceNumber(
        merchant: 'ENEO',
        serviceId: 10039,
        serviceNumber: '203157530',
      );
      print('verifyServiceNumber: ${valid ? "valid" : "invalid"}');
    } on SmobilpayApiException catch (e) {
      if (e.error?.respCode == 40408) {
        print('verifyServiceNumber: service does not support pre-payment '
            'verification (respCode 40408)');
      } else {
        rethrow;
      }
    }

    // Validate a destination against the provider (restricted endpoint).
    try {
      final account = await client.accountValidation.validateAccount(
        destination: '677389120',
        serviceId: 20053,
      );
      print(
          'validateAccount: ${account.status} (${account.name ?? "<no name>"})');
    } on SmobilpayApiException catch (e) {
      if (e.httpStatus == 401) {
        print('validateAccount: restricted endpoint (HTTP 401). Contact '
            'your Maviance integration manager to enable.');
      } else {
        rethrow;
      }
    }
  } finally {
    client.close();
  }
}

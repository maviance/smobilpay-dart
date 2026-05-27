# smobilpay (Dart)

[![pub package](https://img.shields.io/pub/v/smobilpay.svg)](https://pub.dev/packages/smobilpay)
[![CI](https://github.com/maviance/smobilpay-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/maviance/smobilpay-dart/actions/workflows/ci.yml)

Dart client library for the **Smobilpay partner API** (v3.2.0). OAuth 2.0 only.

This is the curated, partner-facing client. It covers every endpoint a partner
integrator needs to move money in and out, sell value-added services, and
drive a payment UI from the static catalog.

> The full README is generated in Task 24. This placeholder satisfies
> `dart pub publish --dry-run` until then.

## Quickstart

```dart
import 'package:smobilpay/smobilpay.dart';

Future<void> main() async {
  final client = SmobilpayClient(
    config: SmobilpayConfig(
      baseUrl: Uri.parse('https://api.example.invalid'),
      publicKey: 'YOUR_PUBLIC_KEY',
      secretKey: 'YOUR_SECRET_KEY',
    ),
  );
  try {
    final pong = await client.verify.ping();
    print('server version: ${pong.version}');
  } finally {
    client.close();
  }
}
```

## License

MIT — see [LICENSE](./LICENSE).

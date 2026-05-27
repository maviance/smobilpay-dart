# smobilpay (Dart)

[![pub package](https://img.shields.io/pub/v/smobilpay.svg)](https://pub.dev/packages/smobilpay)
[![CI](https://github.com/maviance/smobilpay-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/maviance/smobilpay-dart/actions/workflows/ci.yml)

Dart client library for the **Smobilpay partner API** (v3.2.0). OAuth 2.0 only,
hand-written DTOs, zero code generation.

## What this client does

- **Payment collections.** Take payment from a customer's mobile wallet via a
  quote-then-confirm flow. Works for cash-out (generic mobile-money collection),
  bill payment, airtime top-up, voucher purchase, product purchase, and
  subscription top-up.
- **Disbursements.** Send funds into a recipient's mobile wallet from the
  partner's balance using the same quote-then-confirm flow against a `Cashin`
  item.
- **Account and service discovery.** Retrieve the static catalog of merchants,
  services, products, and payment items needed to drive a payment UI.
- **Status verification.** Look up the live status of a previously-issued
  transaction by `ptn` or by your own `trid`, and search historical activity by
  date range.
- **Pre-payment account validation.** Check that a customer's service number is
  well-formed and accepted by the merchant before quoting.

## Requirements

- **Dart `^3.0.0`** at build time and at runtime.
- Network access to the base URL issued by Maviance support.
- An OAuth 2.0 credential pair (`publicKey` / `secretKey`) issued during partner
  onboarding.

The only runtime dependency is `package:http ^1.2.0`. No other packages are
required.

## Installation

```bash
dart pub add smobilpay
```

Or add manually to `pubspec.yaml`:

```yaml
dependencies:
  smobilpay: ^3.2.0
```

## Quickstart

```dart
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
    print('server time: ${pong.time}');
    print('server version: ${pong.version}');
  } finally {
    client.close();
  }
}
```

## Configuration

All options are set on `SmobilpayConfig`:

| Field               | Type            | Default    | Notes                                                  |
|---------------------|-----------------|------------|--------------------------------------------------------|
| `baseUrl`           | `Uri`           | required   | Issued during onboarding; must be `http` or `https`.   |
| `publicKey`         | `String`        | required   | OAuth 2.0 client identifier.                           |
| `secretKey`         | `String`        | required   | OAuth 2.0 client secret.                               |
| `apiVersion`        | `String`        | `'3.0.0'`  | Value of the `x-api-version` header on every request.  |
| `requestTimeout`    | `Duration`      | 30 s       | Per-request timeout for both API and token calls.      |
| `tokenRefreshSkew`  | `Duration`      | 30 s       | Mint a fresh token this far ahead of its expiry.       |
| `httpClient`        | `http.Client?`  | `null`     | Inject a custom client (proxies, custom SSL, tests).   |

When `httpClient` is `null`, the client creates and owns an `http.Client`
internally and closes it when `SmobilpayClient.close()` is called.

## Authentication

The Smobilpay API uses **OAuth 2.0 `client_credentials`** exclusively. Legacy
HMAC request signing is **not** supported.

The client handles token issuance automatically:

1. On the first authenticated request the client POSTs
   `Basic base64(publicKey:secretKey)` to `{baseUrl}/oauth/token` with
   `grant_type=client_credentials`.
2. The returned JWT is cached in memory and attached as
   `Authorization: Bearer <jwt>` on every subsequent request.
3. The token is reused until it is within `tokenRefreshSkew` of expiry; then a
   fresh one is minted automatically.
4. Concurrent mint attempts are de-duplicated — only one HTTP request is issued
   regardless of how many calls are waiting.

To inspect or control the token directly:

```dart
// Force a fresh mint (e.g. after receiving HTTP 401).
await client.tokens.refresh();

// Inspect the currently-cached token (null if never minted).
final tok = client.tokens.cached;
print('expires at: ${tok?.expiresAt}');
```

## Flows

Every payment flow follows the same shape: **discover → quote → confirm**.
The `payItemId` from the discovery step flows into `QuoteRequest`, and the
`quoteId` from the `QuoteResponse` flows into `CollectionRequest`.

### Masterdata discovery

Cache the catalog and refresh it on a schedule:

```dart
import 'package:smobilpay/smobilpay.dart';

final merchants = await client.masterdata.merchants();
final services  = await client.masterdata.services();
```

Each `Service` reports its `type` (which masterdata endpoint to query) and
`isReq*` boolean flags that determine which optional `CollectionRequest` fields
the merchant requires.

### Cash-out (collection)

A `Cashout` item collects funds out of the customer's mobile wallet:

```dart
import 'package:smobilpay/smobilpay.dart';

final cashouts = await client.masterdata.cashouts(serviceId: 20053);
final cashout  = cashouts.first;

final quote = await client.initiate.quote(
  QuoteRequest(amount: 500, payItemId: cashout.payItemId),
);

final response = await client.confirm.collect(
  CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: '237699999999',   // E.164, no leading +
    customerEmailaddress: 'customer@example.com',
    serviceNumber: '237699999999',         // required when service.isReqServiceNumber
    trid: 'ORDER-2026-05-01-0001',         // optional caller reference
    tag: 'retail-front-desk',              // optional label, max 50 chars
  ),
);
print('PTN: ${response.ptn}');
print('status: ${response.status}');      // PENDING on x-api-version 3.0.0
```

### Bill payment

Bills are looked up by `serviceNumber` — not from the static catalog:

```dart
import 'package:smobilpay/smobilpay.dart';

final bills = await client.initiate.bills(
  merchant: 'ENEO',
  serviceId: 10039,
  serviceNumber: 'METER-001',
);
final bill = bills.first;

final quote = await client.initiate.quote(
  QuoteRequest(amount: bill.amountLocalCur!.toInt(), payItemId: bill.payItemId),
);

final response = await client.confirm.collect(
  CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: '237699999999',
    customerEmailaddress: 'customer@example.com',
    serviceNumber: 'METER-001',
    customerName: 'Jane Doe',   // required when service.isReqCustomerName
  ),
);
```

### Airtime top-up

```dart
import 'package:smobilpay/smobilpay.dart';

final topups = await client.masterdata.topups(serviceId: 20051);
final topup  = topups.first;

// FIXED-amount top-ups quote at the catalog price; CUSTOM-amount top-ups
// accept any integer in the local currency.
final amount = topup.amountLocalCur?.toInt() ?? 500;

final quote = await client.initiate.quote(
  QuoteRequest(amount: amount, payItemId: topup.payItemId),
);

final response = await client.confirm.collect(
  CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: '237699999999',
    customerEmailaddress: 'customer@example.com',
    serviceNumber: '237699999999',   // recipient MSISDN
  ),
);
```

### Voucher purchase

The digital redemption code is returned on `CollectionResponse.pin`:

```dart
import 'package:smobilpay/smobilpay.dart';

final vouchers = await client.masterdata.vouchers(serviceId: serviceId);
final voucher  = vouchers.first;

final quote = await client.initiate.quote(
  QuoteRequest(amount: voucher.amountLocalCur!.toInt(), payItemId: voucher.payItemId),
);

final response = await client.confirm.collect(
  CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: customerPhone,
    customerEmailaddress: customerEmail,
  ),
);
print('PIN: ${response.pin}');
```

### Product purchase

Generic products work like vouchers but do not return a redemption PIN:

```dart
import 'package:smobilpay/smobilpay.dart';

final products = await client.masterdata.products(serviceId: serviceId);
final product  = products.first;

final quote = await client.initiate.quote(
  QuoteRequest(amount: product.amountLocalCur!.toInt(), payItemId: product.payItemId),
);

final response = await client.confirm.collect(
  CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: customerPhone,
    customerEmailaddress: customerEmail,
  ),
);
```

### Subscription top-up

Subscriptions (e.g. pay-TV) are looked up by either `serviceNumber` or
`customerNumber`. Pass one and omit the other. The returned list may contain
multiple renewal options for the same subscriber; pick one and quote against its
`payItemId`.

```dart
import 'package:smobilpay/smobilpay.dart';

final subs = await client.initiate.subscriptions(
  merchant: 'CMSABC',
  serviceId: 5000,
  serviceNumber: 'DECODER-001234',
  // customerNumber: '...',   // alternatively pass customerNumber
);
final sub = subs.first;

final quote = await client.initiate.quote(
  QuoteRequest(amount: sub.amountLocalCur!.toInt(), payItemId: sub.payItemId),
);

final response = await client.confirm.collect(
  CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: '237699999999',
    customerEmailaddress: 'customer@example.com',
    serviceNumber: 'DECODER-001234',
    customerName: sub.customerName,
  ),
);
```

### Disbursement (cash-in)

A `Cashin` item sends funds into a recipient's mobile wallet. It uses the same
`/v2/collectstd` endpoint as collections:

```dart
import 'package:smobilpay/smobilpay.dart';

final cashins = await client.masterdata.cashins(serviceId: 20052);
final cashin  = cashins.first;

final quote = await client.initiate.quote(
  QuoteRequest(amount: 10000, payItemId: cashin.payItemId),
);

final response = await client.confirm.collect(
  CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: '237699999999',   // recipient phone
    customerEmailaddress: 'recipient@example.com',
    serviceNumber: '237699999999',         // recipient MSISDN
    trid: 'PAYOUT-2026-05-01-0001',
  ),
);
```

### Quote → confirm with expiry handling

Quotes expire (HTTP `498`). Re-quote and retry when that happens:

```dart
import 'package:smobilpay/smobilpay.dart';

Future<CollectionResponse> collectWithRetry(
  SmobilpayClient client,
  int amount,
  String payItemId,
  String phone,
  String email,
) async {
  while (true) {
    final quote = await client.initiate.quote(
      QuoteRequest(amount: amount, payItemId: payItemId),
    );
    try {
      return await client.confirm.collect(
        CollectionRequest(
          quoteId: quote.quoteId,
          customerPhonenumber: phone,
          customerEmailaddress: email,
        ),
      );
    } on SmobilpayApiException catch (e) {
      if (e.httpStatus == 498) continue; // quote expired — re-quote
      rethrow;
    }
  }
}
```

### Verification and history

```dart
import 'package:smobilpay/smobilpay.dart';

// Liveness check + protocol/version handshake.
final pong = await client.verify.ping();

// Aggregator-level account info: balance, currency, status.
final account = await client.verify.account();

// Live status of a collection by PTN or caller TRID.
final statuses = await client.verify.verifyTransaction(ptn: 'PTN-202605010001');

// Historical lookups — use exactly one of the three methods below.
await client.verify.historyByPtn('PTN-202605010001');
await client.verify.historyByTrid('ORDER-2026-05-01-0001');
await client.verify.historyByDateRange(
  from: DateTime(2026, 5, 1),
  to: DateTime(2026, 5, 31),
);
```

## Error handling

All exceptions extend the sealed class `SmobilpayException`:

| Subtype                        | When thrown                                                              |
|--------------------------------|--------------------------------------------------------------------------|
| `SmobilpayApiException`        | Server returned a non-2xx response with a standard error envelope.       |
| `SmobilpayAuthException`       | OAuth 2.0 token issuance failed (bad credentials, network error, etc.).  |
| `SmobilpayTransportException`  | Connection refused, EOF, timeout, or malformed JSON in a 2xx response.   |
| `SmobilpayConfigException`     | Invalid constructor arguments or missing required method parameters.     |

Because the hierarchy is `sealed`, you can switch exhaustively:

```dart
import 'package:smobilpay/smobilpay.dart';

try {
  final quote = await client.initiate.quote(request);
} on SmobilpayException catch (e) {
  switch (e) {
    case SmobilpayAuthException():
      print('auth failed (HTTP ${e.httpStatus}): ${e.oauthError}');
    case SmobilpayApiException():
      print('API error (HTTP ${e.httpStatus}): ${e.error?.respCode} — ${e.error?.devMsg}');
      if (e.httpStatus == 498) { /* quote expired — re-quote */ }
    case SmobilpayTransportException():
      print('network error on ${e.operation}: ${e.cause}');
    case SmobilpayConfigException():
      print('bad argument: ${e.message}');
  }
}
```

Common `respCode` values:

- `41004` — voucher catalog mismatch (the `payItemId` is not a voucher service).
- `40408` — verify not supported for this service (`isVerifiable: false`).
- HTTP `498` — quote expired; call `initiate.quote(...)` again.
- HTTP `401` on `/v2/validate` — restricted endpoint; compliance review required.

## Account validation

For services that report `isVerifiable: true`, verify the service number before
quoting:

```dart
import 'package:smobilpay/smobilpay.dart';

final valid = await client.accountValidation.verifyServiceNumber(
  merchant: 'ENEO',
  serviceId: 10039,
  serviceNumber: '203157530',
);
```

The `validateAccount` endpoint retrieves the customer name associated with an
MSISDN or contract number. It is a **restricted endpoint** — partners without
compliance clearance receive HTTP 401:

```dart
import 'package:smobilpay/smobilpay.dart';

// Requires prior compliance review by Maviance.
final acct = await client.accountValidation.validateAccount(
  destination: '677389120',
  serviceId: 20053,
);
print('status: ${acct.status}, name: ${acct.name}');
```

## Smoke test

The package ships a built-in smoke-test executable that exercises every flow
against the acceptance environment:

```bash
# 1. Create your local credentials file.
cp smoke-test.example.json smoke-test.json

# 2. Fill in baseUrl, publicKey, secretKey.
$EDITOR smoke-test.json

# 3. Run the smoke test.
dart run smobilpay:smoketest
```

The harness resolves `smoke-test.json` from the working directory, then falls
back to the project root. Any flow block set to `null` (or absent) is skipped
with `SKIP`. By default every collection stops at the quote step and never calls
`/v2/collectstd`.

To exercise a real collect on a specific flow, add the following keys to that
block:

```json
{
  "collect": true,
  "customerPhonenumber": "<payer or recipient MSISDN>",
  "customerEmailaddress": "<receipt email>"
}
```

> **Warning**: opting into `"collect": true` moves real money on the partner
> balance. Use only in an acceptance environment with test credentials.

Cross-client comparison against the Java smoke-test output:

```bash
dart run smobilpay:smoketest > out/dart.log
(cd ../java && ./gradlew runSmokeTest --console=plain) > out/java.log
dart run tool/compare_smoketest.dart --dart out/dart.log --other out/java.log
```

## Onboarding

`baseUrl`, `publicKey`, and `secretKey` are issued by Maviance support during
partner onboarding. Contact **[support@smobilpay.com](mailto:support@smobilpay.com)**.

## Development

```bash
git clone https://github.com/maviance/smobilpay-dart.git
cd smobilpay-dart
dart pub get

dart format .                             # auto-format
dart analyze --fatal-infos                # static analysis (zero warnings)
dart test                                 # unit tests

# Coverage gate (80% line coverage required)
dart test --coverage=coverage/
dart pub global activate coverage         # one-time install
dart pub global run coverage:format_coverage \
    --lcov --in=coverage/ --out=coverage/lcov.info \
    --packages=.dart_tool/package_config.json --report-on=lib
dart run tool/check_coverage.dart coverage/lcov.info 80
```

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the commit style guide and release
checklist, [CHANGELOG.md](./CHANGELOG.md) for version history, and
[UPGRADING.md](./UPGRADING.md) for migration guidance between major versions.

## License

MIT — see [LICENSE](./LICENSE).

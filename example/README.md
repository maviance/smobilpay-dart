# Examples

Runnable Dart programs demonstrating common partner workflows. All four
require these env vars:

```bash
export SMOBILPAY_BASE_URL=https://api.example.invalid
export SMOBILPAY_PUBLIC_KEY=...
export SMOBILPAY_SECRET_KEY=...
```

Run with `dart run example/<name>.dart`.

| File                          | What it demonstrates |
|-------------------------------|----------------------|
| `ping.dart`                   | The smallest end-to-end call: mint a token, ping, print the server version. |
| `catalog.dart`                | Masterdata discovery — list merchants and services, summarize service type distribution. |
| `quote_collection.dart`       | Quote-then-confirm flow with HTTP 498 (quote expired) retry handling. Stops at the quote unless `runCollect` is `true`. |
| `account_validation.dart`     | Pre-payment account checks: `verifyServiceNumber` and `validateAccount`, with appropriate skip handling. |

For a smoke test that exercises every flow against a real environment,
see `bin/smoketest.dart` (run via `dart run smobilpay:smoketest`).

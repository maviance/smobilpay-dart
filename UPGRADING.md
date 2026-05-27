# Upgrading

## From `s3p_signature` 1.x to `smobilpay` 3.2.0

The package has been renamed and rewritten.

- The old package, `s3p_signature`, only provided a single HMAC-SHA1 signing
  helper (`HMACSignature.forGet` / `HMACSignature.forPost`). It is no longer
  published and has no continuing maintenance.
- The new package, `smobilpay`, is a full S3P partner API v3.2.0 client and
  uses OAuth 2.0 `client_credentials` exclusively. HMAC request signing is
  not available.

### Migration

There is no automatic migration path. Partners on `s3p_signature` 1.x must
re-integrate against the partner OpenAPI spec using the new client.

```dart
// Before — s3p_signature 1.x (REMOVED)
final signature = HMACSignature.forPost(
  url: 'https://api.example.invalid/v2/quotestd',
  body: {'amount': 1000, 'payItemId': 'X'},
).generate('secret');

// After — smobilpay 3.2.0
final client = SmobilpayClient(
  config: SmobilpayConfig(
    baseUrl: Uri.parse('https://api.example.invalid'),
    publicKey: 'YOUR_PUBLIC_KEY',
    secretKey: 'YOUR_SECRET_KEY',
  ),
);
final quote = await client.initiate.quote(
  QuoteRequest(amount: 1000, payItemId: 'X'),
);
```

### Auth credentials

The `accessToken` / `accessSecret` pair previously used to sign HMAC requests
is now used as the OAuth `client_credentials` pair. Contact Maviance support
to confirm your existing credentials are enrolled for OAuth 2.0 issuance, or
to receive a new pair.

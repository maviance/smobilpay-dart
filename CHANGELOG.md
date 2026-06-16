# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixed

- `HttpTransport` now performs reactive OAuth token refresh: a `401` on any
  secured request forces a single token refresh and retries the request once,
  instead of surfacing immediately as a `SmobilpayApiException`. This recovers
  from server-side token expiry, clock drift, and revocation that the proactive
  (clock-based) refresh cannot detect. The retry is bounded to one attempt, so
  a genuinely unauthorized request still fails fast (MPAY-30042).

## 3.2.0 — 2026-05-27

### Breaking

- Complete rewrite. The package is now a full S3P partner API v3.2.0 client.
  The v1 HMAC-SHA1 signature helper (`HMACSignature`) has been removed.
- **OAuth 2.0 `client_credentials` is the only supported authentication
  method.** HMAC request signing is no longer available.
- Public API surface is entirely new — see the README and `UPGRADING.md`.

### Added

- `SmobilpayClient` with five API groups: `verify`, `masterdata`,
  `accountValidation`, `initiate`, `confirm`.
- `OAuth2TokenManager` with in-memory token caching, configurable refresh
  skew, and `Completer`-guarded de-duplication of concurrent mint attempts.
- `HttpTransport` with `x-api-version` header injection, JSON request/
  response handling, and an error-envelope-aware exception model.
- Sealed `SmobilpayException` hierarchy: `SmobilpayApiException`,
  `SmobilpayAuthException`, `SmobilpayTransportException`,
  `SmobilpayConfigException`.
- Smoke-test executable: `dart run smobilpay:smoketest`, exercising every
  partner endpoint against a real environment via a JSON config file.

## 1.0.0 — 2025-05-09

- Initial release as `s3p_signature`: a single HMAC-SHA1 signature helper.
  Removed in 3.2.0.

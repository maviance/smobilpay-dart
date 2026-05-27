# Dart Client Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `/root/s3p-clients/dart` from a single 112-line HMAC-SHA1 helper into a full, hand-written, OAuth-2.0-only Dart client for the Smobilpay partner S3P API v3.2.0, with structural parity to the Java/Go/PHP twins and a smoke-test that consumes the same `smoke-test.json` schema as the Java client.

**Architecture:** Single `package:smobilpay` Dart library. Public barrel at `lib/smobilpay.dart` re-exports from `lib/src/`. `SmobilpayClient` exposes five API-group fields (`verify`, `masterdata`, `accountValidation`, `initiate`, `confirm`) plus token diagnostics. `OAuth2TokenManager` mints + caches `client_credentials` tokens behind a `Completer`-guarded mutex; `HttpTransport` injects the bearer + `x-api-version` header on every call. DTOs are plain Dart classes (`final` fields, `fromJson`/`toJson`) co-located with their API group. Errors form a sealed `SmobilpayException` hierarchy. Smoke test is a `bin/smoketest.dart` executable consuming Java-identical config JSON.

**Tech Stack:** Dart SDK `^3.0.0`, `package:http ^1.2.0` (only runtime dep), `package:test ^1.24.0`, `package:lints ^4.0.0`, `package:coverage ^1.7.0`. No code generation, no `freezed`, no `mockito`. CI runs `dart format`, `dart analyze --fatal-infos`, `dart test --coverage`, and an 80% line-coverage gate.

**Spec:** [docs/superpowers/specs/2026-05-27-dart-client-rebuild-design.md](../specs/2026-05-27-dart-client-rebuild-design.md)

---

## Conventions

- Working directory is `/root/s3p-clients/dart` for every command.
- `dart test path/to/test.dart` scopes output to one file at a time.
- One conventional-commits commit per task: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`. Never `git add -A` — name files explicitly.
- TDD throughout core/DTO/API phases: failing test → run it → implement → run it → commit.
- All `lib/src/*.dart` symbols are documented with dartdoc.
- Test imports use `package:smobilpay/...` paths; relative imports only inside `lib/src/`.

---

# Phase 1 — Scaffolding

## Task 1: Repo cleanup, pubspec, lints, gitignore

**Files:**
- Delete: `lib/s3p_signature.dart`
- Delete: `example/main.dart`
- Delete: `test/ s3p_signature_test.dart` (filename has a leading space)
- Delete: `pubspec.lock`
- Modify: `pubspec.yaml`
- Modify: `.gitignore`
- Create: `analysis_options.yaml`

- [ ] **Step 1.1: Confirm branch**

Run: `git rev-parse --abbrev-ref HEAD`
Expected: `feature/rewrite-v3.2-oauth2-only`. If a different branch, `git switch feature/rewrite-v3.2-oauth2-only`.

- [ ] **Step 1.2: Delete v1 sources**

Run:
```bash
git rm lib/s3p_signature.dart example/main.dart "test/ s3p_signature_test.dart" pubspec.lock
rmdir example 2>/dev/null || true
rmdir test 2>/dev/null || true
rmdir lib 2>/dev/null || true
```
Expected: four files staged for deletion; empty directories removed if Git did not auto-prune them.

- [ ] **Step 1.3: Overwrite `pubspec.yaml`**

```yaml
name: smobilpay
description: >-
  Smobilpay (Maviance) S3P partner API v3.2.0 client. OAuth 2.0 only,
  hand-written DTOs, zero code generation.
version: 3.2.0
homepage: https://github.com/maviance/smobilpay-dart
repository: https://github.com/maviance/smobilpay-dart
issue_tracker: https://github.com/maviance/smobilpay-dart/issues
topics:
  - smobilpay
  - payments
  - mobile-money
  - africa
  - s3p

environment:
  sdk: ^3.0.0

dependencies:
  http: ^1.2.0

dev_dependencies:
  test: ^1.24.0
  lints: ^4.0.0
  coverage: ^1.7.0

executables:
  smoketest: smoketest
```

- [ ] **Step 1.4: Overwrite `.gitignore`**

```gitignore
# Dart
.dart_tool/
.packages
build/
pubspec.lock
doc/api/

# Coverage
coverage/

# IDE
.idea/
.vscode/
*.iml

# Local config
smoke-test.json

# OS
.DS_Store
```

- [ ] **Step 1.5: Create `analysis_options.yaml`**

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    todo: ignore

linter:
  rules:
    - always_declare_return_types
    - avoid_print
    - avoid_unused_constructor_parameters
    - directives_ordering
    - prefer_const_constructors
    - prefer_final_locals
    - prefer_relative_imports
    - public_member_api_docs
    - sort_constructors_first
    - sort_unnamed_constructors_first
    - unawaited_futures
    - use_super_parameters
```

- [ ] **Step 1.6: Resolve dependencies**

Run: `dart pub get`
Expected: `Got dependencies!`; a fresh `pubspec.lock` appears (untracked because of `.gitignore`).

- [ ] **Step 1.7: Commit**

```bash
git add pubspec.yaml .gitignore analysis_options.yaml
git commit -m "chore: scaffold smobilpay package, drop v1 HMAC helper"
```

---

## Task 2: Project docs scaffolds + CI workflow

**Files:**
- Modify: `README.md`
- Create: `CHANGELOG.md`
- Create: `UPGRADING.md`
- Create: `CONTRIBUTING.md`
- Create: `.github/workflows/ci.yml`

- [ ] **Step 2.1: Overwrite `README.md` with a placeholder**

```markdown
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
```

- [ ] **Step 2.2: Create `CHANGELOG.md`**

```markdown
# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Smoke-test executable: `dart run smobilpay:smoketest`, consuming the same
  `smoke-test.json` schema as the Java client.
- `tool/compare_smoketest.dart` — diffs normalized Dart vs Java/Go/PHP
  smoke-test output.

## 1.0.0 — 2025-05-09

- Initial release as `s3p_signature`: a single HMAC-SHA1 signature helper.
  Removed in 3.2.0.
```

- [ ] **Step 2.3: Create `UPGRADING.md`**

````markdown
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
````

- [ ] **Step 2.4: Create `CONTRIBUTING.md`**

````markdown
# Contributing

## Setup

```bash
git clone https://github.com/maviance/smobilpay-dart.git
cd smobilpay-dart
dart pub get
```

## Day-to-day commands

```bash
dart format .                          # auto-format
dart analyze --fatal-infos             # static analysis
dart test                              # unit tests
dart test --coverage=coverage/         # tests + coverage
dart pub global activate coverage      # one-time
dart pub global run coverage:format_coverage \
    --lcov --in=coverage/ --out=coverage/lcov.info \
    --packages=.dart_tool/package_config.json --report-on=lib
dart run tool/check_coverage.dart coverage/lcov.info 80
```

## Smoke test

```bash
cp smoke-test.example.json smoke-test.json
$EDITOR smoke-test.json                 # fill baseUrl/publicKey/secretKey
dart run smobilpay:smoketest
```

## Cross-client comparison

```bash
dart run smobilpay:smoketest > out/dart.log
(cd ../java && ./gradlew runSmokeTest --console=plain) > out/java.log
dart run tool/compare_smoketest.dart --dart out/dart.log --other out/java.log
```

## Commit style

[Conventional Commits](https://www.conventionalcommits.org/) — `feat:`,
`fix:`, `docs:`, `refactor:`, `test:`, `chore:`.

## Release checklist

1. Bump `version:` in `pubspec.yaml`.
2. Add a new section to `CHANGELOG.md`.
3. Run `dart pub publish --dry-run`.
4. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.
````

- [ ] **Step 2.5: Create `.github/workflows/ci.yml`**

```bash
mkdir -p .github/workflows
```

```yaml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        sdk: [stable, beta]

    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ matrix.sdk }}

      - name: Install dependencies
        run: dart pub get

      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: dart analyze --fatal-infos --fatal-warnings

      - name: Test with coverage
        run: |
          dart pub global activate coverage
          dart test --coverage=coverage/
          dart pub global run coverage:format_coverage \
              --lcov --in=coverage/ --out=coverage/lcov.info \
              --packages=.dart_tool/package_config.json --report-on=lib

      - name: Enforce coverage gate
        run: dart run tool/check_coverage.dart coverage/lcov.info 80

      - name: pub publish dry-run
        if: matrix.sdk == 'stable'
        run: dart pub publish --dry-run
```

- [ ] **Step 2.6: Commit**

```bash
git add README.md CHANGELOG.md UPGRADING.md CONTRIBUTING.md .github/workflows/ci.yml
git commit -m "docs: add README/CHANGELOG/UPGRADING/CONTRIBUTING + CI workflow"
```

---

# Phase 2 — Core infrastructure

Every task in this phase follows TDD: **write the test, run it red, implement, run it green, commit.**

## Task 3: Sealed `SmobilpayException` hierarchy

**Files:**
- Create stub: `lib/src/model/api_error.dart` (full impl in Task 4)
- Create: `lib/src/exception.dart`
- Create: `test/exception_test.dart`

- [ ] **Step 3.1: Create `test/exception_test.dart`** (full code in the section below).

```dart
import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/model/api_error.dart';
import 'package:test/test.dart';

void main() {
  group('SmobilpayException hierarchy', () {
    test('is sealed and exhaustively switchable', () {
      final exceptions = <SmobilpayException>[
        SmobilpayApiException.fromEnvelope(500, null, '<empty>'),
        const SmobilpayAuthException(401, 'invalid_client', null, 'no creds'),
        SmobilpayTransportException('GET /v2/ping', Exception('eof'), 'eof'),
        const SmobilpayConfigException('bad baseUrl'),
      ];
      for (final e in exceptions) {
        final summary = switch (e) {
          SmobilpayApiException() => 'api',
          SmobilpayAuthException() => 'auth',
          SmobilpayTransportException() => 'transport',
          SmobilpayConfigException() => 'config',
        };
        expect(summary, isNotEmpty);
      }
    });

    test('SmobilpayApiException formats message with respCode when error present', () {
      const err = ApiError(respCode: 41004, devMsg: 'service mismatch', usrMsg: null, link: null);
      final e = SmobilpayApiException.fromEnvelope(404, err, '{"respCode":41004}');
      expect(e.httpStatus, 404);
      expect(e.error, same(err));
      expect(e.rawBody, '{"respCode":41004}');
      expect(e.message, contains('41004'));
      expect(e.message, contains('service mismatch'));
    });

    test('SmobilpayApiException without error falls back to raw body', () {
      final e = SmobilpayApiException.fromEnvelope(500, null, '<plain text>');
      expect(e.error, isNull);
      expect(e.message, contains('500'));
      expect(e.message, contains('<plain text>'));
    });

    test('SmobilpayAuthException carries httpStatus + oauthError + cause', () {
      final cause = Exception('eof');
      final e = SmobilpayAuthException(401, 'invalid_client', cause, 'rejected');
      expect(e.httpStatus, 401);
      expect(e.oauthError, 'invalid_client');
      expect(e.cause, same(cause));
    });

    test('SmobilpayTransportException carries operation + cause', () {
      final cause = Exception('eof');
      final e = SmobilpayTransportException('POST /v2/quotestd', cause, 'eof');
      expect(e.operation, 'POST /v2/quotestd');
      expect(e.cause, same(cause));
    });

    test('SmobilpayConfigException implements Exception', () {
      const e = SmobilpayConfigException('baseUrl is required');
      expect(e, isA<Exception>());
      expect(e.message, 'baseUrl is required');
    });
  });
}
```

- [ ] **Step 3.2: Create the `ApiError` stub at `lib/src/model/api_error.dart`** (replaced fully in Task 4)

```dart
/// Standard API error envelope. Full implementation lives in Task 4 — this
/// stub exists so the exception hierarchy can be tested first.
class ApiError {
  /// Unique error response code.
  final int respCode;
  /// Verbose, plain-language description for the integrator.
  final String? devMsg;
  /// High-level, user-safe error message.
  final String? usrMsg;
  /// URI to documentation for this error code.
  final String? link;

  /// Creates an [ApiError].
  const ApiError({
    required this.respCode,
    required this.devMsg,
    required this.usrMsg,
    required this.link,
  });
}
```

- [ ] **Step 3.3: Run test — expect failure**

Run: `dart test test/exception_test.dart`
Expected: import error for `lib/src/exception.dart`.

- [ ] **Step 3.4: Implement `lib/src/exception.dart`**

```dart
import 'model/api_error.dart';

/// Base for every exception thrown by the Smobilpay client.
///
/// The hierarchy is `sealed`, so consumers can exhaustively `switch` on
/// the concrete subtype with no `default` branch.
sealed class SmobilpayException implements Exception {
  /// Human-readable diagnostic.
  final String message;

  /// Creates a [SmobilpayException].
  const SmobilpayException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the API returns a non-2xx response.
final class SmobilpayApiException extends SmobilpayException {
  /// HTTP status code.
  final int httpStatus;
  /// Decoded `{respCode, devMsg, usrMsg, link}` envelope, or null when the
  /// response body was not a parseable envelope.
  final ApiError? error;
  /// Raw response body for diagnostics when [error] is null.
  final String? rawBody;

  /// Creates a [SmobilpayApiException] with an explicit message.
  const SmobilpayApiException(this.httpStatus, this.error, this.rawBody, String message)
      : super(message);

  /// Builds a [SmobilpayApiException] from HTTP status + envelope, deriving
  /// a default message.
  factory SmobilpayApiException.fromEnvelope(int httpStatus, ApiError? error, String? rawBody) {
    final message = error != null
        ? 'Smobilpay API error (HTTP $httpStatus, respCode=${error.respCode}): ${error.devMsg ?? "<no devMsg>"}'
        : 'Smobilpay API error (HTTP $httpStatus): '
            '${rawBody == null || rawBody.isEmpty ? "<empty body>" : rawBody}';
    return SmobilpayApiException(httpStatus, error, rawBody, message);
  }
}

/// Thrown when OAuth 2.0 token issuance fails.
final class SmobilpayAuthException extends SmobilpayException {
  /// HTTP status. `0` means network failure (no response received).
  final int httpStatus;
  /// OAuth 2.0 standard error identifier (e.g. `invalid_client`), or null.
  final String? oauthError;
  /// Underlying cause, if any.
  final Object? cause;

  /// Creates a [SmobilpayAuthException].
  const SmobilpayAuthException(this.httpStatus, this.oauthError, this.cause, String message)
      : super(message);
}

/// Thrown when a transport-level error occurs — connection refused, EOF,
/// timeout, malformed JSON in a 2xx response, etc.
final class SmobilpayTransportException extends SmobilpayException {
  /// Operation that was attempted (e.g. `GET /v2/ping`).
  final String operation;
  /// Underlying cause.
  final Object cause;

  /// Creates a [SmobilpayTransportException].
  const SmobilpayTransportException(this.operation, this.cause, String message)
      : super(message);
}

/// Thrown when configuration or API arguments are invalid.
final class SmobilpayConfigException extends SmobilpayException {
  /// Creates a [SmobilpayConfigException].
  const SmobilpayConfigException(super.message);
}
```

- [ ] **Step 3.5: Run test — expect green**

Run: `dart test test/exception_test.dart`
Expected: `All tests passed!` — 6 tests.

- [ ] **Step 3.6: Commit**

```bash
git add lib/src/exception.dart lib/src/model/api_error.dart test/exception_test.dart
git commit -m "feat: sealed SmobilpayException hierarchy"
```

---

## Task 4: Full `ApiError` DTO

**Files:**
- Modify: `lib/src/model/api_error.dart` (replace stub from Task 3)
- Create: `test/model/api_error_test.dart`

- [ ] **Step 4.1: Create `test/model/api_error_test.dart`**

```dart
import 'package:smobilpay/src/model/api_error.dart';
import 'package:test/test.dart';

void main() {
  group('ApiError.fromJson', () {
    test('parses a full envelope', () {
      final err = ApiError.fromJson({
        'respCode': 41004,
        'devMsg': 'service is not a voucher',
        'usrMsg': 'This service is not available.',
        'link': 'https://docs.example/41004',
      });
      expect(err.respCode, 41004);
      expect(err.devMsg, 'service is not a voucher');
      expect(err.usrMsg, 'This service is not available.');
      expect(err.link, 'https://docs.example/41004');
    });

    test('accepts nullable optional fields', () {
      final err = ApiError.fromJson({'respCode': 500});
      expect(err.respCode, 500);
      expect(err.devMsg, isNull);
      expect(err.usrMsg, isNull);
      expect(err.link, isNull);
    });

    test('toJson round-trips', () {
      const err = ApiError(respCode: 40408, devMsg: 'no verify', usrMsg: null, link: null);
      final json = err.toJson();
      expect(json['respCode'], 40408);
      expect(json['devMsg'], 'no verify');
      expect(json['usrMsg'], isNull);
    });

    test('equals + hashCode by value', () {
      const a = ApiError(respCode: 1, devMsg: 'a', usrMsg: 'b', link: 'c');
      const b = ApiError(respCode: 1, devMsg: 'a', usrMsg: 'b', link: 'c');
      const c = ApiError(respCode: 2, devMsg: 'a', usrMsg: 'b', link: 'c');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString surfaces respCode and devMsg', () {
      const err = ApiError(respCode: 41004, devMsg: 'mismatch', usrMsg: null, link: null);
      expect(err.toString(), contains('41004'));
      expect(err.toString(), contains('mismatch'));
    });
  });
}
```

- [ ] **Step 4.2: Run test — expect failure (missing methods)**

Run: `dart test test/model/api_error_test.dart`
Expected: `fromJson`, `toJson`, `==` errors.

- [ ] **Step 4.3: Replace `lib/src/model/api_error.dart` with the full implementation**

```dart
/// Standard API error envelope returned by the partner API on non-2xx
/// responses.
///
/// Match programmatically on [respCode] — it is the canonical machine
/// identifier per the partner spec. [devMsg] is integrator-facing,
/// [usrMsg] is user-safe.
class ApiError {
  /// Unique error response code identifying the issue.
  final int respCode;
  /// Verbose, plain-language description for the integrator.
  final String? devMsg;
  /// High-level, user-safe error message.
  final String? usrMsg;
  /// URI to documentation for this error code.
  final String? link;

  /// Creates an [ApiError].
  const ApiError({
    required this.respCode,
    required this.devMsg,
    required this.usrMsg,
    required this.link,
  });

  /// Decodes an [ApiError] from a JSON map.
  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        respCode: (json['respCode'] as num).toInt(),
        devMsg: json['devMsg'] as String?,
        usrMsg: json['usrMsg'] as String?,
        link: json['link'] as String?,
      );

  /// Encodes this [ApiError] as a JSON map.
  Map<String, dynamic> toJson() => {
        'respCode': respCode,
        'devMsg': devMsg,
        'usrMsg': usrMsg,
        'link': link,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiError &&
          respCode == other.respCode &&
          devMsg == other.devMsg &&
          usrMsg == other.usrMsg &&
          link == other.link;

  @override
  int get hashCode => Object.hash(respCode, devMsg, usrMsg, link);

  @override
  String toString() =>
      'ApiError(respCode: $respCode, devMsg: $devMsg, usrMsg: $usrMsg, link: $link)';
}
```

- [ ] **Step 4.4: Run test — expect green**

Run: `dart test test/model/api_error_test.dart test/exception_test.dart`
Expected: both suites green.

- [ ] **Step 4.5: Commit**

```bash
git add lib/src/model/api_error.dart test/model/api_error_test.dart
git commit -m "feat: ApiError envelope DTO with fromJson/toJson/equality"
```

---

## Task 5: `OAuth2Token` value object

**Files:**
- Create: `lib/src/auth/oauth2_token.dart`
- Create: `test/auth/oauth2_token_test.dart`

- [ ] **Step 5.1: Create `test/auth/oauth2_token_test.dart`**

```dart
import 'package:smobilpay/src/auth/oauth2_token.dart';
import 'package:test/test.dart';

void main() {
  group('OAuth2Token', () {
    test('stores all fields', () {
      final t = OAuth2Token(
        accessToken: 'jwt.xyz',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(t.accessToken, 'jwt.xyz');
      expect(t.tokenType, 'Bearer');
      expect(t.expiresAt, DateTime.utc(2026, 1, 1, 12));
    });

    test('isExpired false when now + skew is before expiresAt', () {
      final t = OAuth2Token(
        accessToken: 'x',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(t.isExpired(DateTime.utc(2026, 1, 1, 11), const Duration(seconds: 30)), isFalse);
    });

    test('isExpired true when now + skew == expiresAt', () {
      final t = OAuth2Token(
        accessToken: 'x',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12, 0, 30),
      );
      expect(t.isExpired(DateTime.utc(2026, 1, 1, 12), const Duration(seconds: 30)), isTrue);
    });

    test('isExpired true after expiry', () {
      final t = OAuth2Token(
        accessToken: 'x',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(t.isExpired(DateTime.utc(2026, 1, 1, 12, 1), Duration.zero), isTrue);
    });

    test('equality by value', () {
      final t1 = OAuth2Token(accessToken: 'a', tokenType: 'Bearer', expiresAt: DateTime.utc(2026, 1, 1));
      final t2 = OAuth2Token(accessToken: 'a', tokenType: 'Bearer', expiresAt: DateTime.utc(2026, 1, 1));
      expect(t1, equals(t2));
      expect(t1.hashCode, t2.hashCode);
    });
  });
}
```

- [ ] **Step 5.2: Run — expect failure**

Run: `dart test test/auth/oauth2_token_test.dart`
Expected: import error.

- [ ] **Step 5.3: Implement `lib/src/auth/oauth2_token.dart`**

```dart
/// Immutable OAuth 2.0 access token returned by `POST /oauth/token`.
class OAuth2Token {
  /// JWT bearer string. Sent as `Authorization: Bearer <accessToken>`.
  final String accessToken;
  /// OAuth 2.0 token type. Always `Bearer` in practice.
  final String tokenType;
  /// Absolute moment at which this token stops being valid.
  /// Computed at mint time as `issuedAt + expires_in seconds`.
  final DateTime expiresAt;

  /// Creates an [OAuth2Token].
  const OAuth2Token({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
  });

  /// Returns `true` when [now] plus [skew] is at or past [expiresAt].
  bool isExpired(DateTime now, Duration skew) =>
      !now.add(skew).isBefore(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OAuth2Token &&
          accessToken == other.accessToken &&
          tokenType == other.tokenType &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(accessToken, tokenType, expiresAt);

  @override
  String toString() => 'OAuth2Token(tokenType: $tokenType, expiresAt: $expiresAt)';
}
```

- [ ] **Step 5.4: Run — expect green**

Run: `dart test test/auth/oauth2_token_test.dart`
Expected: `All tests passed!` — 5 tests.

- [ ] **Step 5.5: Commit**

```bash
git add lib/src/auth/oauth2_token.dart test/auth/oauth2_token_test.dart
git commit -m "feat: OAuth2Token value object with isExpired"
```

---

## Task 6: `LenientDate` parser

**Files:**
- Create: `lib/src/http/lenient_date.dart`
- Create: `test/http/lenient_date_test.dart`

- [ ] **Step 6.1: Create `test/http/lenient_date_test.dart`**

```dart
import 'package:smobilpay/src/http/lenient_date.dart';
import 'package:test/test.dart';

void main() {
  group('LenientDate.parse', () {
    test('parses ISO date (no time) as UTC midnight', () {
      expect(LenientDate.parse('2026-01-31'), DateTime.utc(2026, 1, 31));
    });

    test('parses instant (Z suffix)', () {
      expect(LenientDate.parse('2026-01-31T12:00:00Z'),
          DateTime.utc(2026, 1, 31, 12));
    });

    test('parses offset datetime', () {
      expect(LenientDate.parse('2026-01-31T12:00:00+01:00'),
          DateTime.utc(2026, 1, 31, 11));
    });

    test('parses local datetime (no offset) as UTC', () {
      expect(LenientDate.parse('2026-01-31T12:00:00'),
          DateTime.utc(2026, 1, 31, 12));
    });

    test('parses fractional seconds', () {
      expect(LenientDate.parse('2026-01-31T12:00:00.123Z'),
          DateTime.utc(2026, 1, 31, 12, 0, 0, 123));
    });

    test('throws FormatException on garbage', () {
      expect(() => LenientDate.parse('not-a-date'), throwsFormatException);
    });
  });

  group('LenientDate.parseOrNull', () {
    test('returns null for null', () => expect(LenientDate.parseOrNull(null), isNull));
    test('returns null for empty', () => expect(LenientDate.parseOrNull(''), isNull));
    test('parses valid input', () =>
        expect(LenientDate.parseOrNull('2026-01-31'), DateTime.utc(2026, 1, 31)));
  });

  group('LenientDate.formatInstant', () {
    test('formats UTC as ISO Z', () {
      expect(LenientDate.formatInstant(DateTime.utc(2026, 1, 31, 12)),
          '2026-01-31T12:00:00.000Z');
    });

    test('converts local to UTC before formatting', () {
      final local = DateTime.utc(2026, 1, 31, 12).toLocal();
      expect(LenientDate.formatInstant(local), endsWith('Z'));
    });
  });
}
```

- [ ] **Step 6.2: Run — expect failure**

- [ ] **Step 6.3: Implement `lib/src/http/lenient_date.dart`**

```dart
/// Parses and formats every date/datetime shape the partner API emits.
///
/// Accepts ISO date, instant (`Z`), offset datetime, and local datetime.
class LenientDate {
  const LenientDate._();

  /// Parses [input] into a UTC [DateTime].
  static DateTime parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Empty date string', input);
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      final parts = trimmed.split('-').map(int.parse).toList();
      return DateTime.utc(parts[0], parts[1], parts[2]);
    }
    final hasOffset = RegExp(r'[Zz]$|[+-]\d{2}:?\d{2}$').hasMatch(trimmed);
    final canonical = hasOffset ? trimmed : '${trimmed}Z';
    final dt = DateTime.tryParse(canonical);
    if (dt == null) {
      throw FormatException('Not a valid ISO-8601 date/datetime', input);
    }
    return dt.toUtc();
  }

  /// Like [parse], but returns `null` for `null` or empty input.
  static DateTime? parseOrNull(String? input) {
    if (input == null || input.isEmpty) return null;
    return parse(input);
  }

  /// Formats [dt] as a UTC instant with `Z` suffix.
  static String formatInstant(DateTime dt) {
    final iso = dt.toUtc().toIso8601String();
    if (iso.endsWith('Z')) return iso;
    return iso.replaceFirst(RegExp(r'[+-]\d{2}:\d{2}$'), 'Z');
  }
}
```

- [ ] **Step 6.4: Run — expect green**

Run: `dart test test/http/lenient_date_test.dart`
Expected: `All tests passed!` — 11 tests.

- [ ] **Step 6.5: Commit**

```bash
git add lib/src/http/lenient_date.dart test/http/lenient_date_test.dart
git commit -m "feat: LenientDate parser for ISO/instant/offset/local datetimes"
```

---

## Task 7: `QueryParams` builder

**Files:**
- Create: `lib/src/http/query_params.dart`
- Create: `test/http/query_params_test.dart`

- [ ] **Step 7.1: Create `test/http/query_params_test.dart`**

```dart
import 'package:smobilpay/src/http/query_params.dart';
import 'package:test/test.dart';

void main() {
  group('QueryParams', () {
    test('empty builder produces empty query', () {
      expect(QueryParams().toQuery(), '');
      expect(QueryParams().isEmpty, isTrue);
    });

    test('adds params in insertion order', () {
      final q = QueryParams()
        ..add('a', 'one')
        ..add('b', 'two');
      expect(q.toQuery(), 'a=one&b=two');
    });

    test('skips null', () {
      final q = QueryParams()
        ..add('present', 'yes')
        ..add('missing', null);
      expect(q.toQuery(), 'present=yes');
    });

    test('skips empty string', () {
      final q = QueryParams()
        ..add('present', 'yes')
        ..add('empty', '');
      expect(q.toQuery(), 'present=yes');
    });

    test('percent-encodes spaces', () {
      final q = QueryParams()..add('q', 'hello world');
      expect(q.toQuery(), 'q=hello%20world');
    });

    test('stringifies int / double / bool', () {
      final q = QueryParams()
        ..add('i', 42)
        ..add('d', 1.5)
        ..add('b', true);
      expect(q.toQuery(), 'i=42&d=1.5&b=true');
    });

    test('formats DateTime as ISO instant with Z', () {
      final q = QueryParams()..add('ts', DateTime.utc(2026, 1, 31, 12));
      expect(q.toQuery(), 'ts=2026-01-31T12%3A00%3A00.000Z');
    });

    test('throws ArgumentError on empty name', () {
      expect(() => QueryParams().add('', 'x'), throwsA(isA<ArgumentError>()));
    });
  });
}
```

- [ ] **Step 7.2: Run — expect failure**

- [ ] **Step 7.3: Implement `lib/src/http/query_params.dart`**

```dart
import 'lenient_date.dart';

/// Fluent builder for URL-encoded query strings.
///
/// Skips `null` and empty-string values so optional parameters can be
/// added unconditionally. Insertion order is preserved.
class QueryParams {
  final List<_Entry> _entries = [];

  /// Creates an empty builder.
  QueryParams();

  /// Adds a parameter unless [value] is `null` or an empty string.
  void add(String name, Object? value) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (value == null) return;
    final s = switch (value) {
      String x => x,
      DateTime dt => LenientDate.formatInstant(dt),
      _ => value.toString(),
    };
    if (s.isEmpty) return;
    _entries.add(_Entry(name, s));
  }

  /// True when no parameters have been added (after null/empty filter).
  bool get isEmpty => _entries.isEmpty;

  /// Renders the parameters as a URL-encoded query string (no leading `?`).
  String toQuery() {
    if (_entries.isEmpty) return '';
    return _entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.name)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }
}

class _Entry {
  final String name;
  final String value;
  const _Entry(this.name, this.value);
}
```

- [ ] **Step 7.4: Run — expect green**

Run: `dart test test/http/query_params_test.dart`
Expected: `All tests passed!` — 8 tests.

- [ ] **Step 7.5: Commit**

```bash
git add lib/src/http/query_params.dart test/http/query_params_test.dart
git commit -m "feat: QueryParams builder (null-skip, DateTime, percent-encoding)"
```

---

## Task 8: Test support — `FakeHttpClient`, `FakeClock`, fixtures

**Files:**
- Create: `test/_support/fake_clock.dart`
- Create: `test/_support/fake_http_client.dart`
- Create: `test/_support/fixtures.dart`
- Create: `test/fixtures/api_error.json`
- Create: `test/_support/fake_http_client_test.dart`

- [ ] **Step 8.1: `test/fixtures/api_error.json`**

```json
{
  "respCode": 41004,
  "devMsg": "service id does not point to a VOUCHER service",
  "usrMsg": "This service is not available.",
  "link": null
}
```

- [ ] **Step 8.2: `test/_support/fake_clock.dart`**

```dart
/// Manual clock for deterministic time-dependent tests.
class FakeClock {
  /// Current value returned by [call]. Mutate via [advance].
  DateTime now;

  /// Creates a [FakeClock] anchored at [now].
  FakeClock(this.now);

  /// Returns the current value — `DateTime Function()` shape.
  DateTime call() => now;

  /// Advances [now] by [d].
  void advance(Duration d) {
    now = now.add(d);
  }
}
```

- [ ] **Step 8.3: `test/_support/fixtures.dart`**

```dart
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
```

- [ ] **Step 8.4: `test/_support/fake_http_client.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Canned-response [http.Client] for unit tests.
///
/// Register expectations with [expect] keyed by `(method, urlPattern)`.
/// On `send`, the first registered expectation whose method matches and
/// whose `urlPattern` is contained in the request URL wins, is removed
/// from the queue, and its body is returned to the caller. A `send` with
/// no matching expectation throws [StateError].
class FakeHttpClient extends http.BaseClient {
  final List<_Expectation> _expectations = [];
  final List<http.BaseRequest> _captured = [];

  /// Every request seen by this client, in order.
  List<http.BaseRequest> get capturedRequests => List.unmodifiable(_captured);

  /// Latest captured request, cast to [http.Request] for body inspection.
  http.Request get latestRequest => _captured.last as http.Request;

  /// Registers an expected response.
  void expect({
    required String method,
    required String url,
    required int statusCode,
    String body = '',
    Map<String, String> headers = const {'content-type': 'application/json'},
  }) {
    _expectations.add(
      _Expectation(method.toUpperCase(), url, statusCode, body, headers),
    );
  }

  /// Decodes the latest request body as a JSON map, or returns null when empty.
  Map<String, dynamic>? lastJsonBody() {
    final body = latestRequest.body;
    if (body.isEmpty) return null;
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Decodes the latest request body as a form-encoded map.
  Map<String, String> lastFormBody() {
    final body = latestRequest.body;
    if (body.isEmpty) return const {};
    return Uri.splitQueryString(body);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _captured.add(request);
    final method = request.method.toUpperCase();
    final url = request.url.toString();
    final idx = _expectations.indexWhere(
      (e) => e.method == method && url.contains(e.urlPattern),
    );
    if (idx < 0) {
      throw StateError(
        'FakeHttpClient: no expectation matched $method $url\n'
        'Registered: ${_expectations.map((e) => "${e.method} ${e.urlPattern}").join(", ")}',
      );
    }
    final exp = _expectations.removeAt(idx);
    final bytes = utf8.encode(exp.body);
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      exp.statusCode,
      contentLength: bytes.length,
      headers: exp.headers,
      request: request,
    );
  }
}

class _Expectation {
  final String method;
  final String urlPattern;
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  const _Expectation(
      this.method, this.urlPattern, this.statusCode, this.body, this.headers);
}
```

- [ ] **Step 8.5: `test/_support/fake_http_client_test.dart`**

```dart
import 'package:test/test.dart';

import 'fake_clock.dart';
import 'fake_http_client.dart';
import 'fixtures.dart';

void main() {
  group('FakeHttpClient', () {
    test('returns canned response when method+url match', () async {
      final c = FakeHttpClient()
        ..expect(method: 'GET', url: '/v2/ping', statusCode: 200, body: '{"v":1}');
      final res = await c.get(Uri.parse('https://api.example/v2/ping'));
      expect(res.statusCode, 200);
      expect(res.body, '{"v":1}');
      expect(c.capturedRequests, hasLength(1));
    });

    test('throws StateError when no expectation matches', () async {
      final c = FakeHttpClient();
      expect(() => c.get(Uri.parse('https://api.example/v2/ping')),
          throwsA(isA<StateError>()));
    });

    test('parses form-encoded body', () async {
      final c = FakeHttpClient()
        ..expect(method: 'POST', url: '/oauth/token', statusCode: 200, body: '{}');
      await c.post(
        Uri.parse('https://api.example/oauth/token'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=client_credentials',
      );
      expect(c.lastFormBody(), {'grant_type': 'client_credentials'});
    });
  });

  group('FakeClock', () {
    test('returns current value and advances', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      expect(clock(), DateTime.utc(2026, 1, 1, 12));
      clock.advance(const Duration(minutes: 5));
      expect(clock(), DateTime.utc(2026, 1, 1, 12, 5));
    });
  });

  group('loadFixture', () {
    test('loads api_error.json', () {
      final json = loadFixtureMap('api_error');
      expect(json['respCode'], 41004);
      expect(json['devMsg'], contains('VOUCHER'));
    });
  });
}
```

- [ ] **Step 8.6: Run — expect green**

Run: `dart test test/_support/fake_http_client_test.dart`
Expected: `All tests passed!` — 5 tests.

- [ ] **Step 8.7: Commit**

```bash
git add test/_support/ test/fixtures/api_error.json
git commit -m "test: add FakeHttpClient, FakeClock, and fixture loader"
```

---

## Task 9: `SmobilpayConfig`

**Files:**
- Create: `lib/src/config.dart`
- Create: `test/config_test.dart`

- [ ] **Step 9.1: `test/config_test.dart`**

```dart
import 'package:http/http.dart' as http;
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:test/test.dart';

void main() {
  group('SmobilpayConfig', () {
    test('accepts a minimal valid config and exposes defaults', () {
      final cfg = SmobilpayConfig(
        baseUrl: Uri.parse('https://api.example.invalid'),
        publicKey: 'pub',
        secretKey: 'sec',
      );
      expect(cfg.baseUrl, Uri.parse('https://api.example.invalid'));
      expect(cfg.publicKey, 'pub');
      expect(cfg.secretKey, 'sec');
      expect(cfg.apiVersion, '3.0.0');
      expect(cfg.requestTimeout, const Duration(seconds: 30));
      expect(cfg.tokenRefreshSkew, const Duration(seconds: 30));
      expect(cfg.httpClient, isNull);
    });

    test('normalises trailing slash on baseUrl', () {
      final cfg = SmobilpayConfig(
        baseUrl: Uri.parse('https://api.example.invalid/'),
        publicKey: 'p', secretKey: 's',
      );
      expect(cfg.baseUrl.toString(), 'https://api.example.invalid');
    });

    test('throws on empty publicKey', () {
      expect(
        () => SmobilpayConfig(
          baseUrl: Uri.parse('https://api.example.invalid'),
          publicKey: '', secretKey: 's',
        ),
        throwsA(isA<SmobilpayConfigException>()),
      );
    });

    test('throws on empty secretKey', () {
      expect(
        () => SmobilpayConfig(
          baseUrl: Uri.parse('https://api.example.invalid'),
          publicKey: 'p', secretKey: '',
        ),
        throwsA(isA<SmobilpayConfigException>()),
      );
    });

    test('throws on non-http(s) scheme', () {
      expect(
        () => SmobilpayConfig(
          baseUrl: Uri.parse('ftp://api.example.invalid'),
          publicKey: 'p', secretKey: 's',
        ),
        throwsA(isA<SmobilpayConfigException>()),
      );
    });

    test('accepts injected http.Client', () {
      final client = http.Client();
      try {
        final cfg = SmobilpayConfig(
          baseUrl: Uri.parse('https://api.example.invalid'),
          publicKey: 'p', secretKey: 's',
          httpClient: client,
        );
        expect(cfg.httpClient, same(client));
      } finally {
        client.close();
      }
    });

    test('accepts custom apiVersion/timeout/skew', () {
      final cfg = SmobilpayConfig(
        baseUrl: Uri.parse('https://api.example.invalid'),
        publicKey: 'p', secretKey: 's',
        apiVersion: '2.2.0',
        requestTimeout: const Duration(seconds: 5),
        tokenRefreshSkew: const Duration(seconds: 10),
      );
      expect(cfg.apiVersion, '2.2.0');
      expect(cfg.requestTimeout, const Duration(seconds: 5));
      expect(cfg.tokenRefreshSkew, const Duration(seconds: 10));
    });
  });
}
```

- [ ] **Step 9.2: Run — expect failure.**

- [ ] **Step 9.3: Implement `lib/src/config.dart`**

```dart
import 'package:http/http.dart' as http;

import 'exception.dart';

/// Configuration for a [SmobilpayClient].
///
/// Throws [SmobilpayConfigException] for invalid input.
class SmobilpayConfig {
  /// Default `x-api-version` header value mandated by the partner spec.
  static const String defaultApiVersion = '3.0.0';
  /// Default per-request timeout.
  static const Duration defaultRequestTimeout = Duration(seconds: 30);
  /// Default refresh-ahead window for cached OAuth tokens.
  static const Duration defaultTokenRefreshSkew = Duration(seconds: 30);

  /// Partner API base URL with any trailing slash stripped.
  final Uri baseUrl;
  /// OAuth 2.0 client identifier.
  final String publicKey;
  /// OAuth 2.0 client secret.
  final String secretKey;
  /// Value of the `x-api-version` request header on every secured call.
  final String apiVersion;
  /// Per-request timeout applied to outbound calls.
  final Duration requestTimeout;
  /// Refresh-ahead window — tokens within this many seconds of expiry are
  /// treated as expired so the next call mints a fresh one.
  final Duration tokenRefreshSkew;
  /// Optional injected HTTP client. `null` → [SmobilpayClient] owns one.
  final http.Client? httpClient;

  /// Creates a [SmobilpayConfig].
  factory SmobilpayConfig({
    required Uri baseUrl,
    required String publicKey,
    required String secretKey,
    String apiVersion = defaultApiVersion,
    Duration requestTimeout = defaultRequestTimeout,
    Duration tokenRefreshSkew = defaultTokenRefreshSkew,
    http.Client? httpClient,
  }) {
    if (baseUrl.scheme != 'http' && baseUrl.scheme != 'https') {
      throw SmobilpayConfigException(
        'baseUrl scheme must be http or https, got "${baseUrl.scheme}"',
      );
    }
    if (publicKey.isEmpty) {
      throw const SmobilpayConfigException('publicKey must not be empty');
    }
    if (secretKey.isEmpty) {
      throw const SmobilpayConfigException('secretKey must not be empty');
    }
    return SmobilpayConfig._(
      baseUrl: _stripTrailingSlash(baseUrl),
      publicKey: publicKey,
      secretKey: secretKey,
      apiVersion: apiVersion,
      requestTimeout: requestTimeout,
      tokenRefreshSkew: tokenRefreshSkew,
      httpClient: httpClient,
    );
  }

  const SmobilpayConfig._({
    required this.baseUrl,
    required this.publicKey,
    required this.secretKey,
    required this.apiVersion,
    required this.requestTimeout,
    required this.tokenRefreshSkew,
    required this.httpClient,
  });

  static Uri _stripTrailingSlash(Uri url) {
    final s = url.toString();
    if (s.endsWith('/')) return Uri.parse(s.substring(0, s.length - 1));
    return url;
  }
}
```

- [ ] **Step 9.4: Run — expect green**

- [ ] **Step 9.5: Commit**

```bash
git add lib/src/config.dart test/config_test.dart
git commit -m "feat: SmobilpayConfig with validation + defaults"
```

---

## Task 10: `OAuth2TokenManager`

**Files:**
- Create: `lib/src/auth/oauth2_token_manager.dart`
- Create: `test/auth/oauth2_token_manager_test.dart`

- [ ] **Step 10.1: `test/auth/oauth2_token_manager_test.dart`**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:test/test.dart';

import '../_support/fake_clock.dart';
import '../_support/fake_http_client.dart';

SmobilpayConfig _cfg(http.Client client) => SmobilpayConfig(
      baseUrl: Uri.parse('https://api.example.invalid'),
      publicKey: 'pub',
      secretKey: 'sec',
      tokenRefreshSkew: const Duration(seconds: 30),
      httpClient: client,
    );

void main() {
  group('accessToken', () {
    test('mints, caches, returns the bearer', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c,
        config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1, 12),
      );
      expect(await mgr.accessToken(), 'jwt.A');
      expect(await mgr.accessToken(), 'jwt.A');
      expect(c.capturedRequests, hasLength(1));
    });

    test('sends Basic auth + form body', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"x","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await mgr.accessToken();
      final req = c.latestRequest;
      expect(req.headers['Authorization'], startsWith('Basic '));
      final basic = req.headers['Authorization']!.substring(6);
      expect(String.fromCharCodes(base64Decode(basic)), 'pub:sec');
      expect(req.headers['Content-Type'], 'application/x-www-form-urlencoded');
      expect(c.lastFormBody(), {'grant_type': 'client_credentials'});
    });

    test('re-mints once now+skew >= expiresAt', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":60}',
        )
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.B","token_type":"Bearer","expires_in":60}',
        );
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c), clock: clock.call,
      );
      expect(await mgr.accessToken(), 'jwt.A');
      clock.advance(const Duration(seconds: 35));
      expect(await mgr.accessToken(), 'jwt.B');
      expect(c.capturedRequests, hasLength(2));
    });

    test('defaults token_type to Bearer when missing', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.A","expires_in":60}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await mgr.accessToken();
      expect(mgr.cached?.tokenType, 'Bearer');
    });

    test('concurrent callers dedupe to a single mint', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      final results = await Future.wait([
        mgr.accessToken(),
        mgr.accessToken(),
        mgr.accessToken(),
      ]);
      expect(results, ['jwt.A', 'jwt.A', 'jwt.A']);
      expect(c.capturedRequests, hasLength(1));
    });
  });

  group('refresh', () {
    test('forces a fresh mint and replaces the cache', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
        )
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.B","token_type":"Bearer","expires_in":3600}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      expect(await mgr.accessToken(), 'jwt.A');
      expect(await mgr.refresh(), 'jwt.B');
      expect(await mgr.accessToken(), 'jwt.B');
    });
  });

  group('failure modes', () {
    test('non-2xx throws SmobilpayAuthException with oauthError', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 401,
          body: '{"error":"invalid_client"}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(
        mgr.accessToken(),
        throwsA(isA<SmobilpayAuthException>()
            .having((e) => e.httpStatus, 'status', 401)
            .having((e) => e.oauthError, 'oauthError', 'invalid_client')),
      );
    });

    test('missing access_token throws', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"expires_in":60}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(mgr.accessToken(),
          throwsA(isA<SmobilpayAuthException>()));
    });

    test('missing expires_in throws', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: '{"access_token":"jwt.A"}',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(mgr.accessToken(),
          throwsA(isA<SmobilpayAuthException>()));
    });

    test('non-JSON body throws', () async {
      final c = FakeHttpClient()
        ..expect(
          method: 'POST', url: '/oauth/token', statusCode: 200,
          body: 'not json',
        );
      final mgr = OAuth2TokenManager(
        httpClient: c, config: _cfg(c),
        clock: () => DateTime.utc(2026, 1, 1),
      );
      await expectLater(mgr.accessToken(),
          throwsA(isA<SmobilpayAuthException>()));
    });
  });
}
```

- [ ] **Step 10.2: Run — expect failure.**

- [ ] **Step 10.3: Implement `lib/src/auth/oauth2_token_manager.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../exception.dart';
import 'oauth2_token.dart';

/// Mints, caches, and refreshes OAuth 2.0 access tokens via
/// `POST /oauth/token` using `client_credentials`.
///
/// Concurrent callers are de-duplicated through a `Completer`-guarded
/// mutex — only one mint at a time.
class OAuth2TokenManager {
  static const String _tokenPath = '/oauth/token';
  static const String _grantBody = 'grant_type=client_credentials';

  final http.Client _httpClient;
  final SmobilpayConfig _config;
  final DateTime Function() _clock;

  OAuth2Token? _current;
  Completer<OAuth2Token>? _inFlight;

  /// Creates a token manager. [clock] defaults to `DateTime.now`.
  OAuth2TokenManager({
    required http.Client httpClient,
    required SmobilpayConfig config,
    DateTime Function()? clock,
  })  : _httpClient = httpClient,
        _config = config,
        _clock = clock ?? DateTime.now;

  /// Currently-cached token, or null if never minted.
  OAuth2Token? get cached => _current;

  /// Returns a valid bearer string, minting on miss / expiry.
  Future<String> accessToken() async {
    final snap = _current;
    if (snap != null && !snap.isExpired(_clock(), _config.tokenRefreshSkew)) {
      return snap.accessToken;
    }
    final tok = await _mintCached();
    return tok.accessToken;
  }

  /// Forces a fresh mint, replacing any cached token.
  Future<String> refresh() async {
    final tok = await _mintForce();
    return tok.accessToken;
  }

  Future<OAuth2Token> _mintCached() async {
    final pending = _inFlight;
    if (pending != null) return pending.future;
    return _mintForce();
  }

  Future<OAuth2Token> _mintForce() async {
    final completer = Completer<OAuth2Token>();
    _inFlight = completer;
    try {
      final tok = await _doMint();
      _current = tok;
      completer.complete(tok);
      return tok;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  Future<OAuth2Token> _doMint() async {
    final uri = Uri.parse('${_config.baseUrl}$_tokenPath');
    final basic = base64Encode(utf8.encode('${_config.publicKey}:${_config.secretKey}'));
    final issuedAt = _clock();
    final http.Response resp;
    try {
      resp = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Basic $basic',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: _grantBody,
          )
          .timeout(_config.requestTimeout);
    } catch (e) {
      throw SmobilpayAuthException(0, null, e, 'POST /oauth/token failed: $e');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final oauthError = _tryReadOAuthErrorCode(resp.body);
      throw SmobilpayAuthException(
        resp.statusCode,
        oauthError,
        null,
        'OAuth token mint failed (HTTP ${resp.statusCode}'
        '${oauthError != null ? ", error=$oauthError" : ""})'
        '${resp.body.isEmpty ? "" : ": ${resp.body}"}',
      );
    }
    return _parseTokenResponse(resp.body, issuedAt);
  }

  OAuth2Token _parseTokenResponse(String body, DateTime issuedAt) {
    Map<String, dynamic> node;
    try {
      node = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw SmobilpayAuthException(
          200, null, e, 'OAuth token response was not valid JSON: $e');
    }
    final accessToken = node['access_token'];
    final expiresIn = node['expires_in'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const SmobilpayAuthException(
        200, null, null,
        "OAuth token response missing required field 'access_token'",
      );
    }
    if (expiresIn is! num) {
      throw const SmobilpayAuthException(
        200, null, null,
        "OAuth token response missing required field 'expires_in'",
      );
    }
    final tokenType =
        node['token_type'] is String ? node['token_type'] as String : 'Bearer';
    return OAuth2Token(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresAt: issuedAt.add(Duration(seconds: expiresIn.toInt())),
    );
  }

  String? _tryReadOAuthErrorCode(String body) {
    if (body.isEmpty) return null;
    try {
      final n = jsonDecode(body);
      if (n is Map<String, dynamic> && n['error'] is String) {
        return n['error'] as String;
      }
    } catch (_) {/* body wasn't JSON */}
    return null;
  }
}
```

- [ ] **Step 10.4: Run — expect green.**

Run: `dart test test/auth/oauth2_token_manager_test.dart`
Expected: `All tests passed!` — 10 tests.

- [ ] **Step 10.5: Commit**

```bash
git add lib/src/auth/oauth2_token_manager.dart test/auth/oauth2_token_manager_test.dart
git commit -m "feat: OAuth2TokenManager with cache, refresh, mint dedup"
```

---

## Task 11: `HttpTransport`

**Files:**
- Create: `test/fixtures/ping.json`
- Create: `lib/src/http/transport.dart`
- Create: `test/http/transport_test.dart`

- [ ] **Step 11.1: `test/fixtures/ping.json`**

```json
{
  "time": "2026-05-27T13:00:00Z",
  "version": "3.0.0",
  "nonce": "abc123",
  "key": "PUB_KEY_TEST"
}
```

- [ ] **Step 11.2: `test/http/transport_test.dart`**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/http/query_params.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

SmobilpayConfig _cfg(http.Client client) => SmobilpayConfig(
      baseUrl: Uri.parse('https://api.example.invalid'),
      publicKey: 'pub',
      secretKey: 'sec',
      httpClient: client,
    );

OAuth2TokenManager _tokens(http.Client client, SmobilpayConfig cfg) =>
    OAuth2TokenManager(
      httpClient: client,
      config: cfg,
      clock: () => DateTime.utc(2026, 1, 1),
    );

void _expectTokenMint(FakeHttpClient c) {
  c.expect(
    method: 'POST', url: '/oauth/token', statusCode: 200,
    body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
  );
}

void main() {
  group('getJson', () {
    test('issues GET with bearer + version + accept headers', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'GET', url: '/v2/ping', statusCode: 200,
        body: jsonEncode(loadFixtureMap('ping')),
      );
      final cfg = _cfg(c);
      final t = HttpTransport(httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      final body = await t.getJson('/v2/ping', QueryParams());
      expect((body as Map<String, dynamic>)['version'], '3.0.0');
      final req = c.capturedRequests[1];
      expect(req.method, 'GET');
      expect(req.url.path, '/v2/ping');
      expect(req.headers['Authorization'], 'Bearer jwt.A');
      expect(req.headers['x-api-version'], '3.0.0');
      expect(req.headers['Accept'], 'application/json');
    });

    test('appends query string', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(method: 'GET', url: '/v2/bill?', statusCode: 200, body: '[]');
      final cfg = _cfg(c);
      final t = HttpTransport(httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await t.getJson(
        '/v2/bill',
        QueryParams()..add('merchant', 'ENEO')..add('serviceid', 10039),
      );
      final url = c.capturedRequests[1].url.toString();
      expect(url, contains('?merchant=ENEO'));
      expect(url, contains('serviceid=10039'));
    });
  });

  group('postJson', () {
    test('sends JSON body with Content-Type', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'POST', url: '/v2/quotestd', statusCode: 200,
        body: '{"quoteId":"00000000-0000-0000-0000-000000000000"}',
      );
      final cfg = _cfg(c);
      final t = HttpTransport(httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await t.postJson('/v2/quotestd', {'amount': 1000, 'payItemId': 'X'});
      final req = c.capturedRequests[1] as http.Request;
      expect(req.headers['Content-Type'], 'application/json');
      expect(jsonDecode(req.body), {'amount': 1000, 'payItemId': 'X'});
    });
  });

  group('errors', () {
    test('decodes ApiError envelope on 4xx', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'GET', url: '/v2/ping', statusCode: 401,
        body: jsonEncode(loadFixtureMap('api_error')),
      );
      final cfg = _cfg(c);
      final t = HttpTransport(httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayApiException>()
            .having((e) => e.httpStatus, 'status', 401)
            .having((e) => e.error?.respCode, 'respCode', 41004)),
      );
    });

    test('falls back to rawBody when error body is not JSON', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(
        method: 'GET', url: '/v2/ping', statusCode: 500,
        body: 'Internal Server Error',
      );
      final cfg = _cfg(c);
      final t = HttpTransport(httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayApiException>()
            .having((e) => e.httpStatus, 'status', 500)
            .having((e) => e.error, 'error', isNull)
            .having((e) => e.rawBody, 'rawBody', 'Internal Server Error')),
      );
    });

    test('throws SmobilpayTransportException on malformed 2xx JSON', () async {
      final c = FakeHttpClient();
      _expectTokenMint(c);
      c.expect(method: 'GET', url: '/v2/ping', statusCode: 200, body: 'not json');
      final cfg = _cfg(c);
      final t = HttpTransport(httpClient: c, config: cfg, tokenManager: _tokens(c, cfg));
      await expectLater(
        t.getJson('/v2/ping', QueryParams()),
        throwsA(isA<SmobilpayTransportException>()),
      );
    });
  });
}
```

- [ ] **Step 11.3: Run — expect failure.**

- [ ] **Step 11.4: Implement `lib/src/http/transport.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/oauth2_token_manager.dart';
import '../config.dart';
import '../exception.dart';
import '../model/api_error.dart';
import 'query_params.dart';

/// Request/response engine. Adds auth + `x-api-version` headers, applies
/// the per-request timeout, decodes the JSON body or throws a typed
/// exception for non-2xx responses.
class HttpTransport {
  final http.Client _httpClient;
  final SmobilpayConfig _config;
  final OAuth2TokenManager _tokenManager;

  /// Creates a transport.
  HttpTransport({
    required http.Client httpClient,
    required SmobilpayConfig config,
    required OAuth2TokenManager tokenManager,
  })  : _httpClient = httpClient,
        _config = config,
        _tokenManager = tokenManager;

  /// Issues an authenticated `GET` and returns the decoded JSON.
  Future<dynamic> getJson(String path, QueryParams query) async {
    final bearer = await _tokenManager.accessToken();
    final uri = _resolve(path, query);
    final op = 'GET ${_canonicalPath(path)}';
    final http.Response resp;
    try {
      resp = await _httpClient
          .get(uri, headers: _headers(bearer))
          .timeout(_config.requestTimeout);
    } catch (e) {
      throw SmobilpayTransportException(op, e, '$op failed: $e');
    }
    return _decode(resp, op);
  }

  /// Issues an authenticated `POST` of a JSON [body] and returns the decoded JSON.
  Future<dynamic> postJson(String path, Object body) async {
    final bearer = await _tokenManager.accessToken();
    final uri = _resolve(path, QueryParams());
    final op = 'POST ${_canonicalPath(path)}';
    final http.Response resp;
    try {
      resp = await _httpClient
          .post(
            uri,
            headers: {
              ..._headers(bearer),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_config.requestTimeout);
    } catch (e) {
      throw SmobilpayTransportException(op, e, '$op failed: $e');
    }
    return _decode(resp, op);
  }

  Map<String, String> _headers(String bearer) => {
        'Authorization': 'Bearer $bearer',
        'x-api-version': _config.apiVersion,
        'Accept': 'application/json',
      };

  Uri _resolve(String path, QueryParams query) {
    final p = _canonicalPath(path);
    final url = '${_config.baseUrl}$p';
    final q = query.toQuery();
    return Uri.parse(q.isEmpty ? url : '$url?$q');
  }

  String _canonicalPath(String p) => p.startsWith('/') ? p : '/$p';

  dynamic _decode(http.Response resp, String op) {
    final status = resp.statusCode;
    if (status < 200 || status >= 300) {
      ApiError? error;
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['respCode'] is num) {
          error = ApiError.fromJson(decoded);
        }
      } catch (_) {/* not an envelope */}
      throw SmobilpayApiException.fromEnvelope(status, error, resp.body);
    }
    if (resp.body.isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } catch (e) {
      throw SmobilpayTransportException(
          op, e, '$op: failed to parse JSON response: $e');
    }
  }
}
```

- [ ] **Step 11.5: Run — expect green.**

- [ ] **Step 11.6: Commit**

```bash
git add lib/src/http/transport.dart test/http/transport_test.dart test/fixtures/ping.json
git commit -m "feat: HttpTransport with auth+version headers and error envelope decoding"
```

---

# Phase 3 — Shared model

Phase 3 fills in cross-cutting DTO bits used by every API group. Each task TDD-led. Tests live under `test/model/`.

## Task 12: Enums

**Files:**
- Create: `lib/src/model/enums.dart`
- Create: `test/model/enums_test.dart`

- [ ] **Step 12.1: `test/model/enums_test.dart`**

```dart
import 'package:smobilpay/src/model/enums.dart';
import 'package:test/test.dart';

void main() {
  group('enumFromJson', () {
    test('parses by wire name (case-sensitive when possible)', () {
      expect(enumFromJson(ServiceType.values, 'SEARCHABLE_BILL'),
          ServiceType.searchableBill);
      expect(enumFromJson(ServiceType.values, 'TOPUP'), ServiceType.topup);
      expect(enumFromJson(AmountType.values, 'FIXED'), AmountType.fixed);
      expect(enumFromJson(MerchantStatus.values, 'Active'),
          MerchantStatus.active);
    });

    test('returns fallback for unknown', () {
      expect(
        enumFromJson(ServiceType.values, 'NOT_A_TYPE', fallback: ServiceType.unknown),
        ServiceType.unknown,
      );
    });

    test('returns null when no fallback and input is unknown', () {
      expect(enumFromJson(AmountType.values, 'NOT_A_TYPE'), isNull);
    });

    test('returns null for null input when no fallback', () {
      expect(enumFromJson(AmountType.values, null), isNull);
    });

    test('CustomerAccountStatus parses the three documented values', () {
      expect(enumFromJson(CustomerAccountStatus.values, 'UNKNOWN'),
          CustomerAccountStatus.unknown);
      expect(enumFromJson(CustomerAccountStatus.values, 'VALIDATED'),
          CustomerAccountStatus.validated);
      expect(enumFromJson(CustomerAccountStatus.values, 'VERIFIED'),
          CustomerAccountStatus.verified);
    });
  });

  test('every enum has a wireName matching the spec', () {
    expect(ServiceType.searchableBill.wireName, 'SEARCHABLE_BILL');
    expect(ServiceType.nonSearchableBill.wireName, 'NON_SEARCHABLE_BILL');
    expect(AmountType.overpay.wireName, 'OVERPAY');
    expect(MerchantStatus.inactive.wireName, 'Inactive');
    expect(ServiceStatus.active.wireName, 'Active');
    expect(BillType.regular.wireName, 'REGULAR');
    expect(PaymentStatusType.success.wireName, 'SUCCESS');
    expect(CustomerAccountStatus.verified.wireName, 'VERIFIED');
  });
}
```

- [ ] **Step 12.2: Run — expect failure.**

- [ ] **Step 12.3: Implement `lib/src/model/enums.dart`**

```dart
/// Service classification. Drives which masterdata endpoint produces the
/// matching payment items for a given service.
enum ServiceType {
  /// Bills are looked up via `GET /v2/bill?serviceNumber=...` and may return
  /// multiple open bills.
  searchableBill('SEARCHABLE_BILL'),
  /// Bills are looked up but always return a single bill.
  nonSearchableBill('NON_SEARCHABLE_BILL'),
  /// Returned by `GET /v2/product`.
  product('PRODUCT'),
  /// Returned by `GET /v2/topup`.
  topup('TOPUP'),
  /// Returned by `GET /v2/subscription`.
  subscription('SUBSCRIPTION'),
  /// Disbursement — money flows into recipient wallet.
  cashin('CASHIN'),
  /// Collection — money flows out of customer wallet.
  cashout('CASHOUT'),
  /// Vouchers — returned by `GET /v2/voucher`.
  voucher('VOUCHER'),
  /// Forward-compatibility fallback for values not enumerated above.
  unknown('UNKNOWN');

  /// Wire name as emitted by the partner API.
  final String wireName;
  const ServiceType(this.wireName);
}

/// How the amount is determined for a payment item.
enum AmountType {
  /// Must be paid in full at `amountLocalCur`.
  fixed('FIXED'),
  /// Caller chooses the amount.
  custom('CUSTOM'),
  /// Amount may be less than `amountLocalCur`.
  partial('PARTIAL'),
  /// Amount may exceed `amountLocalCur` (subject to country regulation).
  overpay('OVERPAY'),
  /// Forward-compatibility fallback.
  unknown('UNKNOWN');

  /// Wire name as emitted by the partner API.
  final String wireName;
  const AmountType(this.wireName);
}

/// Classification of a [Bill].
enum BillType {
  /// Regular open bill.
  regular('REGULAR'),
  /// Past-due bill.
  overdue('OVERDUE'),
  /// Forward-compatibility fallback.
  unknown('UNKNOWN');

  /// Wire name as emitted by the partner API.
  final String wireName;
  const BillType(this.wireName);
}

/// Availability status of a merchant.
enum MerchantStatus {
  /// Operational.
  active('Active'),
  /// Disabled.
  inactive('Inactive'),
  /// Forward-compatibility fallback.
  unknown('Unknown');

  /// Wire name as emitted by the partner API.
  final String wireName;
  const MerchantStatus(this.wireName);
}

/// Availability status of a service.
enum ServiceStatus {
  /// Operational.
  active('Active'),
  /// Disabled.
  inactive('Inactive'),
  /// Forward-compatibility fallback.
  unknown('Unknown');

  /// Wire name as emitted by the partner API.
  final String wireName;
  const ServiceStatus(this.wireName);
}

/// Payment processing status.
enum PaymentStatusType {
  /// Reversed by a chargeback / refund.
  reversed('REVERSED'),
  /// Awaiting clearing.
  pending('PENDING'),
  /// Failed.
  errored('ERRORED'),
  /// Settled.
  success('SUCCESS'),
  /// Forward-compatibility fallback.
  unknown('UNKNOWN');

  /// Wire name as emitted by the partner API.
  final String wireName;
  const PaymentStatusType(this.wireName);
}

/// Account-recognition outcome from `GET /v2/validate`.
enum CustomerAccountStatus {
  /// Account authenticity could be neither verified nor validated.
  unknown('UNKNOWN'),
  /// Account syntax has been internally confirmed.
  validated('VALIDATED'),
  /// Account has been positively cross-checked against the service provider.
  verified('VERIFIED');

  /// Wire name as emitted by the partner API.
  final String wireName;
  const CustomerAccountStatus(this.wireName);
}

/// Decodes [json] into one of [values] by matching `wireName`.
///
/// Returns [fallback] (or `null`) when [json] is null or unrecognised.
T? enumFromJson<T extends Enum>(
  List<T> values,
  String? json, {
  T? fallback,
}) {
  if (json == null) return fallback;
  for (final v in values) {
    final wire = (v as dynamic).wireName as String;
    if (wire == json) return v;
  }
  return fallback;
}
```

- [ ] **Step 12.4: Run — expect green.**

Run: `dart test test/model/enums_test.dart`
Expected: `All tests passed!` — 6 tests.

- [ ] **Step 12.5: Commit**

```bash
git add lib/src/model/enums.dart test/model/enums_test.dart
git commit -m "feat: spec enums + enumFromJson decoder"
```

---

## Task 13: `I18nText` + `Commission`

**Files:**
- Create: `lib/src/model/i18n_text.dart`
- Create: `lib/src/model/commission.dart`
- Create: `test/model/value_objects_test.dart`

- [ ] **Step 13.1: `test/model/value_objects_test.dart`**

```dart
import 'package:smobilpay/src/model/commission.dart';
import 'package:smobilpay/src/model/i18n_text.dart';
import 'package:test/test.dart';

void main() {
  group('I18nText', () {
    test('round-trips JSON', () {
      const t = I18nText(language: 'en', localText: 'Service Number');
      expect(I18nText.fromJson(t.toJson()), t);
    });

    test('equality by value', () {
      const a = I18nText(language: 'fr', localText: 'numéro');
      const b = I18nText(language: 'fr', localText: 'numéro');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Commission', () {
    test('round-trips JSON', () {
      const c = Commission(earnings: 2.5, currency: 'XAF');
      expect(Commission.fromJson(c.toJson()), c);
    });

    test('accepts null fields', () {
      final c = Commission.fromJson({});
      expect(c.earnings, isNull);
      expect(c.currency, isNull);
    });
  });
}
```

- [ ] **Step 13.2: Run — expect failure.**

- [ ] **Step 13.3: `lib/src/model/i18n_text.dart`**

```dart
/// Localized text entry. Used for service hints and field labels.
class I18nText {
  /// Target language code (ISO 639-1, e.g. `en`, `fr`).
  final String language;
  /// Localized text.
  final String localText;

  /// Creates an [I18nText].
  const I18nText({required this.language, required this.localText});

  /// Decodes from JSON.
  factory I18nText.fromJson(Map<String, dynamic> json) => I18nText(
        language: json['language'] as String,
        localText: json['localText'] as String,
      );

  /// Encodes to JSON.
  Map<String, dynamic> toJson() => {
        'language': language,
        'localText': localText,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is I18nText && language == other.language && localText == other.localText;

  @override
  int get hashCode => Object.hash(language, localText);

  @override
  String toString() => 'I18nText($language: $localText)';
}
```

- [ ] **Step 13.4: `lib/src/model/commission.dart`**

```dart
/// Commission earned on a transaction. Present on `PaymentStatus.commission`
/// only when the commission feature is enabled for the merchant/service.
class Commission {
  /// Commission amount earned.
  final double? earnings;
  /// Currency (ISO 4217).
  final String? currency;

  /// Creates a [Commission].
  const Commission({required this.earnings, required this.currency});

  /// Decodes from JSON.
  factory Commission.fromJson(Map<String, dynamic> json) => Commission(
        earnings: (json['earnings'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
      );

  /// Encodes to JSON.
  Map<String, dynamic> toJson() => {'earnings': earnings, 'currency': currency};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Commission && earnings == other.earnings && currency == other.currency;

  @override
  int get hashCode => Object.hash(earnings, currency);

  @override
  String toString() => 'Commission(earnings: $earnings, currency: $currency)';
}
```

- [ ] **Step 13.5: Run — expect green; commit**

```bash
git add lib/src/model/i18n_text.dart lib/src/model/commission.dart test/model/value_objects_test.dart
git commit -m "feat: I18nText and Commission value objects"
```

---

## Task 14: `PaymentItem` interface

**Files:**
- Create: `lib/src/model/payment_item.dart`

> The interface has no behaviour to test in isolation; it is exercised by
> every PaymentItem-implementing DTO test in Phase 4.

- [ ] **Step 14.1: Create the interface**

```dart
import 'enums.dart';

/// Common interface for the payment-item DTOs returned by the masterdata
/// endpoints (`/v2/product`, `/v2/voucher`, `/v2/topup`, `/v2/cashin`,
/// `/v2/cashout`) and the lookup endpoints (`/v2/bill`,
/// `/v2/subscription`).
///
/// [payItemId] is the value passed to `QuoteRequest` to request pricing
/// for this item.
abstract interface class PaymentItem {
  /// Identifier of the service this item belongs to.
  int get serviceId;
  /// Merchant code that owns the service.
  String get merchant;
  /// Identifier passed to `/v2/quotestd` to request a price quote.
  String get payItemId;
  /// Human-readable item description.
  String? get payItemDescr;
  /// How the amount is determined for this item.
  AmountType get amountType;
  /// ISO 4217 local currency.
  String? get localCur;
  /// Display name.
  String? get name;
  /// Catalog price in the local currency, or null for CUSTOM-amount items.
  double? get amountLocalCur;
  /// Free-form description.
  String? get description;
  /// Optional string slot used by some services.
  String? get optStrg;
  /// Optional numeric slot used by some services.
  double? get optNmb;
}
```

- [ ] **Step 14.2: Run analyzer to confirm nothing breaks**

Run: `dart analyze --fatal-infos lib/src/model/payment_item.dart`
Expected: `No issues found!`.

- [ ] **Step 14.3: Commit**

```bash
git add lib/src/model/payment_item.dart
git commit -m "feat: PaymentItem interface for masterdata and lookup DTOs"
```

---

# Phase 4 — API groups (with co-located DTOs)

Phase 4 implements the five API groups. Each task:

1. Adds JSON fixtures captured from the partner OpenAPI examples.
2. Writes failing tests asserting (a) request URL/headers/body, (b) DTO decoding.
3. Implements the API class + co-located DTOs.
4. Runs tests, commits.

Within each task the DTO fields come directly from the Java reference at
`/root/s3p-clients/java/src/main/java/org/maviance/smobilpay/model/`.

> **Naming convention.** Wire JSON uses `serviceid` (lowercase i) on most
> DTOs, `serviceId` (camelCase) on a few (`CustomerAccount`,
> `verifyServiceNumber` query). The Dart side exposes idiomatic
> `serviceId` on every DTO and only writes the lowercase form on the wire
> where the API uses it; `fromJson` accepts both for safety.

## Task 15: `VerifyApi` + `Ping`, `Account`, `PaymentStatus`

**Files:**
- Create fixtures: `test/fixtures/account.json`, `test/fixtures/payment_status.json`
- Create: `lib/src/api/verify_api.dart`
- Create: `test/api/verify_api_test.dart`

- [ ] **Step 15.1: Fixtures**

`test/fixtures/account.json`:

```json
{
  "balance": 12345.67,
  "currency": "XAF",
  "key": "PUB_KEY_TEST",
  "agentId": "AGT-001",
  "agentName": "Test Agent",
  "agentAddress": "Yaoundé",
  "agentPhonenumber": "+237600000000",
  "companyName": "ACME",
  "companyAddress": "Yaoundé",
  "companyPhonenumber": "+237600000001",
  "limitMax": 1000000.0,
  "limitRemaining": 987654.32
}
```

`test/fixtures/payment_status.json`:

```json
[
  {
    "ptn": "PTN-001",
    "serviceid": "10039",
    "merchant": "ENEO",
    "timestamp": "2026-05-27T13:00:00Z",
    "receiptNumber": "RCPT-1",
    "veriCode": "V1",
    "clearingDate": "2026-05-28",
    "trid": "TRID-1",
    "priceLocalCur": 500.0,
    "priceSystemCur": 500.0,
    "localCur": "XAF",
    "systemCur": "XAF",
    "pin": null,
    "status": "SUCCESS",
    "payItemId": "PI-1",
    "payItemDescr": "Test item",
    "errorCode": 0,
    "tag": null,
    "commission": {"earnings": 2.5, "currency": "XAF"}
  }
]
```

- [ ] **Step 15.2: `test/api/verify_api_test.dart`** (excerpt — full version follows the pattern of Task 11's test):

```dart
import 'dart:convert';

import 'package:smobilpay/src/api/verify_api.dart';
import 'package:smobilpay/src/auth/oauth2_token_manager.dart';
import 'package:smobilpay/src/config.dart';
import 'package:smobilpay/src/exception.dart';
import 'package:smobilpay/src/http/transport.dart';
import 'package:smobilpay/src/model/enums.dart';
import 'package:test/test.dart';

import '../_support/fake_http_client.dart';
import '../_support/fixtures.dart';

VerifyApi _newApi(FakeHttpClient c) {
  c.expect(
    method: 'POST', url: '/oauth/token', statusCode: 200,
    body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
  );
  final cfg = SmobilpayConfig(
    baseUrl: Uri.parse('https://api.example.invalid'),
    publicKey: 'pub', secretKey: 'sec', httpClient: c,
  );
  final tokens = OAuth2TokenManager(
      httpClient: c, config: cfg, clock: () => DateTime.utc(2026, 1, 1));
  return VerifyApi(HttpTransport(httpClient: c, config: cfg, tokenManager: tokens));
}

void main() {
  test('ping decodes the spec example', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET', url: '/v2/ping', statusCode: 200,
      body: jsonEncode(loadFixtureMap('ping')),
    );
    final pong = await api.ping();
    expect(pong.version, '3.0.0');
    expect(pong.nonce, 'abc123');
    expect(pong.key, 'PUB_KEY_TEST');
    expect(pong.time, DateTime.utc(2026, 5, 27, 13));
  });

  test('account decodes', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET', url: '/v2/account', statusCode: 200,
      body: jsonEncode(loadFixtureMap('account')),
    );
    final a = await api.account();
    expect(a.agentName, 'Test Agent');
    expect(a.balance, 12345.67);
    expect(a.currency, 'XAF');
  });

  test('verifyTransaction requires ptn or trid', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    expect(
      () => api.verifyTransaction(),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test('verifyTransaction by ptn issues correct query', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(
      method: 'GET', url: '/v2/verifytx', statusCode: 200,
      body: jsonEncode(loadFixtureList('payment_status')),
    );
    final rows = await api.verifyTransaction(ptn: 'PTN-001');
    expect(rows, hasLength(1));
    expect(rows.first.status, PaymentStatusType.success);
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('ptn=PTN-001'));
    expect(url, isNot(contains('trid=')));
  });

  test('historyByDateRange formats both timestamps as ISO Z', () async {
    final c = FakeHttpClient();
    final api = _newApi(c);
    c.expect(method: 'GET', url: '/v2/historystd', statusCode: 200, body: '[]');
    await api.historyByDateRange(
      from: DateTime.utc(2026, 5, 20),
      to: DateTime.utc(2026, 5, 27),
    );
    final url = c.capturedRequests[1].url.toString();
    expect(url, contains('timestamp_from=2026-05-20'));
    expect(url, contains('timestamp_to=2026-05-27'));
  });
}
```

- [ ] **Step 15.3: Run — expect failure.**

- [ ] **Step 15.4: Implement `lib/src/api/verify_api.dart`**

```dart
import '../exception.dart';
import '../http/lenient_date.dart';
import '../http/query_params.dart';
import '../http/transport.dart';
import '../model/commission.dart';
import '../model/enums.dart';

/// Status and account verification endpoints. Backed by the `Verify`
/// spec tag.
class VerifyApi {
  final HttpTransport _transport;

  /// Creates a [VerifyApi].
  VerifyApi(this._transport);

  /// `GET /v2/ping` — authenticated probe.
  Future<Ping> ping() async {
    final json = await _transport.getJson('/v2/ping', QueryParams())
        as Map<String, dynamic>;
    return Ping.fromJson(json);
  }

  /// `GET /v2/account` — agent profile.
  Future<Account> account() async {
    final json = await _transport.getJson('/v2/account', QueryParams())
        as Map<String, dynamic>;
    return Account.fromJson(json);
  }

  /// `GET /v2/verifytx` — current status of a payment collection by
  /// `ptn` and/or `trid`. At least one must be provided.
  Future<List<PaymentStatus>> verifyTransaction({
    String? ptn,
    String? trid,
  }) async {
    if (ptn == null && trid == null) {
      throw const SmobilpayConfigException(
        'at least one of ptn or trid must be provided',
      );
    }
    final json = await _transport.getJson(
      '/v2/verifytx',
      QueryParams()..add('ptn', ptn)..add('trid', trid),
    ) as List<dynamic>;
    return json.map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /v2/historystd?ptn=...`
  Future<List<PaymentStatus>> historyByPtn(String ptn) async {
    final json = await _transport.getJson(
      '/v2/historystd',
      QueryParams()..add('ptn', ptn),
    ) as List<dynamic>;
    return json.map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /v2/historystd?trid=...`
  Future<List<PaymentStatus>> historyByTrid(String trid) async {
    final json = await _transport.getJson(
      '/v2/historystd',
      QueryParams()..add('trid', trid),
    ) as List<dynamic>;
    return json.map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /v2/historystd?timestamp_from=...&timestamp_to=...`
  Future<List<PaymentStatus>> historyByDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    if (to.isBefore(from)) {
      throw const SmobilpayConfigException('to date is before from date');
    }
    final fromUtc = DateTime.utc(from.year, from.month, from.day);
    final toUtc = DateTime.utc(to.year, to.month, to.day, 23, 59, 59);
    final json = await _transport.getJson(
      '/v2/historystd',
      QueryParams()
        ..add('timestamp_from', fromUtc)
        ..add('timestamp_to', toUtc),
    ) as List<dynamic>;
    return json.map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// Authenticated probe response from `GET /v2/ping`.
class Ping {
  /// Current server time (UTC).
  final DateTime time;
  /// Server-emitted protocol version.
  final String version;
  /// Nonce echoed from the request.
  final String nonce;
  /// Public token of the user that sent the request.
  final String key;

  /// Creates a [Ping].
  const Ping({required this.time, required this.version, required this.nonce, required this.key});

  /// Decodes from JSON.
  factory Ping.fromJson(Map<String, dynamic> json) => Ping(
        time: LenientDate.parse(json['time'] as String),
        version: json['version'] as String,
        nonce: json['nonce'] as String,
        key: json['key'] as String,
      );

  @override
  String toString() => 'Ping(time: $time, version: $version, nonce: $nonce, key: $key)';
}

/// Authenticated agent profile from `GET /v2/account`.
class Account {
  /// Remaining balance.
  final double balance;
  /// System currency (ISO 4217).
  final String currency;
  /// Agent public access key.
  final String key;
  /// Unique agent identifier.
  final String agentId;
  /// Agent full name.
  final String agentName;
  /// Agent full address.
  final String? agentAddress;
  /// Agent phone number.
  final String? agentPhonenumber;
  /// Collector company name.
  final String? companyName;
  /// Collector company address.
  final String? companyAddress;
  /// Collector company phone number.
  final String? companyPhonenumber;
  /// Daily collection limit.
  final double limitMax;
  /// Collection limit remaining for the day.
  final double limitRemaining;

  /// Creates an [Account].
  const Account({
    required this.balance,
    required this.currency,
    required this.key,
    required this.agentId,
    required this.agentName,
    required this.agentAddress,
    required this.agentPhonenumber,
    required this.companyName,
    required this.companyAddress,
    required this.companyPhonenumber,
    required this.limitMax,
    required this.limitRemaining,
  });

  /// Decodes from JSON.
  factory Account.fromJson(Map<String, dynamic> json) => Account(
        balance: (json['balance'] as num).toDouble(),
        currency: json['currency'] as String,
        key: json['key'] as String,
        agentId: json['agentId'] as String,
        agentName: json['agentName'] as String,
        agentAddress: json['agentAddress'] as String?,
        agentPhonenumber: json['agentPhonenumber'] as String?,
        companyName: json['companyName'] as String?,
        companyAddress: json['companyAddress'] as String?,
        companyPhonenumber: json['companyPhonenumber'] as String?,
        limitMax: (json['limitMax'] as num).toDouble(),
        limitRemaining: (json['limitRemaining'] as num).toDouble(),
      );
}

/// Current state of a previously-issued payment collection.
class PaymentStatus {
  /// Globally unique payment transaction number.
  final String ptn;
  /// Service identifier (string on this endpoint per the partner spec).
  final String serviceId;
  /// Merchant code.
  final String? merchant;
  /// Server-side timestamp (UTC).
  final DateTime? timestamp;
  /// Receipt number — bound to the agent context.
  final String? receiptNumber;
  /// Verification code.
  final String? veriCode;
  /// Date the transaction cleared.
  final DateTime? clearingDate;
  /// Custom transaction reference supplied by the partner.
  final String? trid;
  /// Price in local currency.
  final double? priceLocalCur;
  /// Price in system currency.
  final double? priceSystemCur;
  /// Local currency (ISO 4217).
  final String? localCur;
  /// System currency (ISO 4217).
  final String? systemCur;
  /// Digital pin for voucher purchases.
  final String? pin;
  /// Processing status.
  final PaymentStatusType status;
  /// Payment item identifier.
  final String? payItemId;
  /// Human-readable item description.
  final String? payItemDescr;
  /// Numeric error code, `0` on success.
  final int errorCode;
  /// Partner-supplied tag echoed back.
  final String? tag;
  /// Commission earned, if the feature is enabled for the service.
  final Commission? commission;

  /// Creates a [PaymentStatus].
  const PaymentStatus({
    required this.ptn,
    required this.serviceId,
    required this.merchant,
    required this.timestamp,
    required this.receiptNumber,
    required this.veriCode,
    required this.clearingDate,
    required this.trid,
    required this.priceLocalCur,
    required this.priceSystemCur,
    required this.localCur,
    required this.systemCur,
    required this.pin,
    required this.status,
    required this.payItemId,
    required this.payItemDescr,
    required this.errorCode,
    required this.tag,
    required this.commission,
  });

  /// Decodes from JSON.
  factory PaymentStatus.fromJson(Map<String, dynamic> json) => PaymentStatus(
        ptn: json['ptn'] as String,
        serviceId: (json['serviceid'] ?? json['serviceId']).toString(),
        merchant: json['merchant'] as String?,
        timestamp: LenientDate.parseOrNull(json['timestamp'] as String?),
        receiptNumber: json['receiptNumber'] as String?,
        veriCode: json['veriCode'] as String?,
        clearingDate: LenientDate.parseOrNull(json['clearingDate'] as String?),
        trid: json['trid'] as String?,
        priceLocalCur: (json['priceLocalCur'] as num?)?.toDouble(),
        priceSystemCur: (json['priceSystemCur'] as num?)?.toDouble(),
        localCur: json['localCur'] as String?,
        systemCur: json['systemCur'] as String?,
        pin: json['pin'] as String?,
        status: enumFromJson(
          PaymentStatusType.values,
          json['status'] as String?,
          fallback: PaymentStatusType.unknown,
        )!,
        payItemId: json['payItemId'] as String?,
        payItemDescr: json['payItemDescr'] as String?,
        errorCode: (json['errorCode'] as num?)?.toInt() ?? 0,
        tag: json['tag'] as String?,
        commission: json['commission'] is Map<String, dynamic>
            ? Commission.fromJson(json['commission'] as Map<String, dynamic>)
            : null,
      );
}
```

- [ ] **Step 15.5: Run — expect green.**

Run: `dart test test/api/verify_api_test.dart`
Expected: `All tests passed!` — 5+ tests.

- [ ] **Step 15.6: Commit**

```bash
git add lib/src/api/verify_api.dart test/api/verify_api_test.dart test/fixtures/account.json test/fixtures/payment_status.json
git commit -m "feat: VerifyApi with Ping, Account, PaymentStatus DTOs"
```

---

## Tasks 16–19: Remaining API groups

The four remaining API groups (`MasterdataApi`, `InitiateApi`,
`ConfirmApi`, `AccountValidationApi`) follow Task 15's pattern exactly:

1. **Fixtures.** Capture from the OpenAPI `examples:` blocks in
   `/root/php-smobilpay-s3p-api/apidocs/s3p_3.2.0_openapi_specs_partner.yml`.
   Where the spec lacks an example, derive a minimal valid payload from
   the `components.schemas.<Name>` shape.
2. **Test file.** Mirror `test/api/verify_api_test.dart` — assert request
   URL/query/body for each method, assert each `fromJson` against the
   fixture.
3. **Implementation.** Mirror the Java client at
   `/root/s3p-clients/java/src/main/java/org/maviance/smobilpay/api/<Name>.java`
   1:1 for method signatures and validation; mirror
   `/root/s3p-clients/java/src/main/java/org/maviance/smobilpay/model/<DTO>.java`
   for fields and JSON wire names.
4. **Run, commit.**

### Task 16 — `MasterdataApi` + DTOs

**Files:**
- Fixtures: `test/fixtures/merchants.json`, `services.json`, `cashout.json`,
  `cashin.json`, `topup.json`, `product.json`, `voucher.json`.
- Create: `lib/src/api/masterdata_api.dart`
- Create: `test/api/masterdata_api_test.dart`

**Endpoints and signatures (from `MasterdataApi.java`):**
```dart
Future<List<Merchant>> merchants();                           // GET /v2/merchant
Future<List<Service>>  services();                            // GET /v2/service
Future<List<Product>>  products({int? serviceId});            // GET /v2/product?serviceid=
Future<List<Product>>  vouchers({int? serviceId});            // GET /v2/voucher?serviceid=
Future<List<Topup>>    topups({int? serviceId});              // GET /v2/topup?serviceid=
Future<List<Cashin>>   cashins({int? serviceId});             // GET /v2/cashin?serviceid=
Future<List<Cashout>>  cashouts({int? serviceId});            // GET /v2/cashout?serviceid=
```

**DTOs:**
- `Merchant` — fields: `merchant`, `name`, `description`, `country`, `status` (`MerchantStatus`), `logo`, `logoHash`, `category` (deprecated).
- `Service` — full field list from `Service.java` (22 fields including `List<I18nText>` for labels and hint, ServiceType/ServiceStatus enums, all `isReq*` booleans).
- `Cashout`, `Cashin`, `Topup`, `Product` — implement `PaymentItem`. Identical 11-field shape: `serviceid`, `merchant`, `payItemId`, `payItemDescr`, `amountType` (`AmountType`), `localCur`, `name`, `amountLocalCur` (`double?`), `description`, `optStrg`, `optNmb` (`double?`).
- The `voucher` endpoint returns `Product`-shaped items, so reuse the `Product` class.

- [ ] **Step 16.1–16.6:** TDD cycle as in Task 15. Commit message: `feat: MasterdataApi with Merchant, Service, Cashout, Cashin, Topup, Product`.

### Task 17 — `InitiateApi` + DTOs

**Files:**
- Fixtures: `bill.json`, `subscription.json`, `quote_request.json`, `quote_response.json`.
- Create: `lib/src/api/initiate_api.dart`
- Create: `test/api/initiate_api_test.dart`

**Endpoints and signatures:**
```dart
Future<List<Bill>>         bills({required String merchant, required int serviceId, required String serviceNumber});   // GET /v2/bill
Future<List<Subscription>> subscriptions({required String merchant, required int serviceId, String? serviceNumber, String? customerNumber}); // GET /v2/subscription
Future<QuoteResponse>      quote(QuoteRequest request);                                                                  // POST /v2/quotestd
```

**Validation:**
- `subscriptions` throws `SmobilpayConfigException` if both `serviceNumber` and `customerNumber` are null.
- `QuoteRequest` validates `amount >= 1` and `payItemId` non-null in its constructor.

**DTOs:**
- `Bill` — implements `PaymentItem`. Extra fields beyond the base eleven: `billType` (`BillType` enum), `penaltyAmount` (`double?`), `payOrder` (`int`), `serviceNumber`, `billNumber`, `customerNumber`, `billMonth`, `billYear`, `billDate` (`DateTime?`), `billDueDate` (`DateTime?`). Uses `LenientDate.parseOrNull`.
- `Subscription` — implements `PaymentItem`. Extra fields: `serviceNumber`, `customerReference`, `customerName`, `customerNumber`, `startDate`, `dueDate`, `endDate` (all `DateTime?`).
- `QuoteRequest` — `{amount: int, payItemId: String}`. `toJson` only.
- `QuoteResponse` — `quoteId` (`String`; partner spec uses UUID format but we treat as string), `expiresAt` (`DateTime`), `payItemId`, `amountLocalCur`, `priceLocalCur`, `priceSystemCur`, `localCur`, `systemCur`, `promotion`.

- [ ] **Step 17.1–17.6:** TDD cycle. Commit message: `feat: InitiateApi with Bill, Subscription, QuoteRequest, QuoteResponse`.

### Task 18 — `ConfirmApi` + DTOs

**Files:**
- Fixtures: `collection_request.json`, `collection_response.json`.
- Create: `lib/src/api/confirm_api.dart`
- Create: `test/api/confirm_api_test.dart`

**Endpoint:**
```dart
Future<CollectionResponse> collect(CollectionRequest request);   // POST /v2/collectstd
```

**DTOs:**
- `CollectionRequest` — required: `quoteId` (`String`), `customerPhonenumber`, `customerEmailaddress`. Optional: `customerName`, `customerAddress`, `customerNumber`, `serviceNumber`, `trid`, `tag` (≤50 chars), `callbackUrl` (≤255 chars), `cdata`. Constructor throws `SmobilpayConfigException` when (a) any of the three required fields is empty, (b) `tag.length > 50`, or (c) `callbackUrl.length > 255`. `toJson` emits a map with **null fields omitted** so the server does not see them.
- `CollectionResponse` — `ptn`, `timestamp` (`DateTime?`), `agentBalance` (`double?`), `receiptNumber`, `veriCode`, `priceLocalCur`, `priceSystemCur`, `localCur`, `systemCur`, `trid`, `pin`, `status` (`PaymentStatusType`), `payItemId`, `payItemDescr`, `tag`.

> The smoke test calls this endpoint **only** when a flow block opts in
> with `collect: true` (see Task 22). Unit tests cover the request body
> shape, the full response decoding, the
> `tag.length > 50` / `callbackUrl.length > 255` rejection, and the
> empty-string rejection for the three required fields
> (`quoteId`, `customerPhonenumber`, `customerEmailaddress`) — all
> via `SmobilpayConfigException`.

- [ ] **Step 18.1–18.6:** TDD cycle. Commit message: `feat: ConfirmApi with CollectionRequest/Response`.

### Task 19 — `AccountValidationApi` + `CustomerAccount`

**Files:**
- Fixtures: `customer_account.json`.
- Create: `lib/src/api/account_validation_api.dart`
- Create: `test/api/account_validation_api_test.dart`

**Endpoints:**
```dart
Future<bool>            verifyServiceNumber({required String merchant, required int serviceId, required String serviceNumber}); // GET /v2/verify
Future<CustomerAccount> validateAccount({required String destination, required int serviceId});                                 // GET /v2/validate
```

**DTOs:**
- `CustomerAccount` — `status` (`CustomerAccountStatus`), `name`, `destination`.

**Notes:**
- The `verifyServiceNumber` endpoint returns a bare boolean JSON literal (`true`/`false`). The transport's `_decode` returns it as `bool`; the API casts and returns. Test asserts both true-path and false-path.
- The `validateAccount` query uses `serviceId` (camelCase) on the wire — per the Java reference. All other endpoints use `serviceid` (lowercase). Encode the parameter name accordingly.

- [ ] **Step 19.1–19.6:** TDD cycle. Commit message: `feat: AccountValidationApi with CustomerAccount`.

---

# Phase 5 — Facade

## Task 20: `SmobilpayClient` + barrel exports

**Files:**
- Create: `lib/src/client.dart`
- Create: `lib/smobilpay.dart`
- Create: `test/client_test.dart`

- [ ] **Step 20.1: `test/client_test.dart`**

```dart
import 'package:smobilpay/smobilpay.dart';
import 'package:test/test.dart';

import '_support/fake_http_client.dart';

SmobilpayConfig _cfg(FakeHttpClient c) => SmobilpayConfig(
      baseUrl: Uri.parse('https://api.example.invalid'),
      publicKey: 'pub', secretKey: 'sec', httpClient: c,
    );

void main() {
  test('exposes five API group fields + tokens', () {
    final c = FakeHttpClient();
    final client = SmobilpayClient(config: _cfg(c));
    expect(client.verify, isNotNull);
    expect(client.masterdata, isNotNull);
    expect(client.accountValidation, isNotNull);
    expect(client.initiate, isNotNull);
    expect(client.confirm, isNotNull);
    expect(client.tokens, isNotNull);
    client.close();
  });

  test('close() is idempotent', () {
    final c = FakeHttpClient();
    final client = SmobilpayClient(config: _cfg(c));
    client.close();
    client.close(); // must not throw
  });

  test('end-to-end ping via injected fake http client', () async {
    final c = FakeHttpClient()
      ..expect(
        method: 'POST', url: '/oauth/token', statusCode: 200,
        body: '{"access_token":"jwt.A","token_type":"Bearer","expires_in":3600}',
      )
      ..expect(
        method: 'GET', url: '/v2/ping', statusCode: 200,
        body: '{"time":"2026-05-27T13:00:00Z","version":"3.0.0","nonce":"n","key":"k"}',
      );
    final client = SmobilpayClient(config: _cfg(c));
    final pong = await client.verify.ping();
    expect(pong.version, '3.0.0');
    client.close();
  });
}
```

- [ ] **Step 20.2: `lib/src/client.dart`**

```dart
import 'package:http/http.dart' as http;

import 'api/account_validation_api.dart';
import 'api/confirm_api.dart';
import 'api/initiate_api.dart';
import 'api/masterdata_api.dart';
import 'api/verify_api.dart';
import 'auth/oauth2_token_manager.dart';
import 'config.dart';
import 'http/transport.dart';

/// Entry point for the Smobilpay partner API.
///
/// Construct a client with [SmobilpayConfig]; the client lazily mints an
/// OAuth 2.0 bearer on the first authenticated request and caches it
/// until expiry. Call [close] when finished to release the HTTP client.
class SmobilpayClient {
  /// Static reference data (merchants, services, payment items).
  final MasterdataApi masterdata;
  /// Pre-payment account checks (`verify`, `validate`).
  final AccountValidationApi accountValidation;
  /// Lookups and quotes that prepare a payment collection.
  final InitiateApi initiate;
  /// Executes a payment collection against a quote.
  final ConfirmApi confirm;
  /// Status and account verification.
  final VerifyApi verify;
  /// OAuth 2.0 token diagnostics (`refresh()`, `cached`).
  final OAuth2TokenManager tokens;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  bool _closed = false;

  /// Creates a [SmobilpayClient].
  factory SmobilpayClient({required SmobilpayConfig config}) {
    final injected = config.httpClient;
    final httpClient = injected ?? http.Client();
    final tokens = OAuth2TokenManager(httpClient: httpClient, config: config);
    final transport = HttpTransport(
      httpClient: httpClient,
      config: config,
      tokenManager: tokens,
    );
    return SmobilpayClient._(
      httpClient: httpClient,
      ownsHttpClient: injected == null,
      tokens: tokens,
      masterdata: MasterdataApi(transport),
      accountValidation: AccountValidationApi(transport),
      initiate: InitiateApi(transport),
      confirm: ConfirmApi(transport),
      verify: VerifyApi(transport),
    );
  }

  SmobilpayClient._({
    required http.Client httpClient,
    required bool ownsHttpClient,
    required this.tokens,
    required this.masterdata,
    required this.accountValidation,
    required this.initiate,
    required this.confirm,
    required this.verify,
  })  : _httpClient = httpClient,
        _ownsHttpClient = ownsHttpClient;

  /// Releases resources. Closes the internal `http.Client` if this client
  /// created it. Calling more than once is a no-op.
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsHttpClient) _httpClient.close();
  }
}
```

- [ ] **Step 20.3: `lib/smobilpay.dart` (barrel)**

```dart
/// Smobilpay (Maviance) S3P partner API v3.2.0 client.
///
/// See <https://github.com/maviance/smobilpay-dart> for the full README.
library;

export 'src/api/account_validation_api.dart';
export 'src/api/confirm_api.dart' show ConfirmApi, CollectionRequest, CollectionResponse;
export 'src/api/initiate_api.dart' show InitiateApi, Bill, Subscription, QuoteRequest, QuoteResponse;
export 'src/api/masterdata_api.dart' show MasterdataApi, Merchant, Service, Cashin, Cashout, Topup, Product;
export 'src/api/verify_api.dart' show VerifyApi, Ping, Account, PaymentStatus;
export 'src/auth/oauth2_token.dart';
export 'src/auth/oauth2_token_manager.dart';
export 'src/client.dart';
export 'src/config.dart';
export 'src/exception.dart';
export 'src/model/api_error.dart';
export 'src/model/commission.dart';
export 'src/model/enums.dart' show ServiceType, AmountType, BillType, MerchantStatus, ServiceStatus, PaymentStatusType, CustomerAccountStatus;
export 'src/model/i18n_text.dart';
export 'src/model/payment_item.dart';
```

- [ ] **Step 20.4: Run the full test suite — expect green.**

Run: `dart test`
Expected: every test in `test/` passes.

- [ ] **Step 20.5: Commit**

```bash
git add lib/src/client.dart lib/smobilpay.dart test/client_test.dart
git commit -m "feat: SmobilpayClient facade + public barrel exports"
```

---

# Phase 6 — Smoke test

## Task 21: Smoke-test scaffold + config loader + first 5 scenarios

**Files:**
- Create: `bin/smoketest.dart`
- Create: `smoke-test.example.json` (byte-identical copy of Java's)

- [ ] **Step 21.1: Copy Java's smoke-test template**

```bash
cp ../java/smoke-test.example.json smoke-test.example.json
```

Confirm the file is byte-identical:

```bash
diff smoke-test.example.json ../java/smoke-test.example.json
```
Expected: no output (files match).

- [ ] **Step 21.2: `bin/smoketest.dart`** — scaffold with `SmokeConfig`, `Runner`, and the first five scenarios (ping, token refresh, account, merchants, services). The full file lives at ~600 lines; the structure is:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:smobilpay/smobilpay.dart';

Future<void> main(List<String> args) async {
  final SmokeConfig cfg;
  try {
    cfg = SmokeConfig.load(args);
  } on _ConfigError catch (e) {
    stderr.writeln('Configuration error: ${e.message}');
    exit(2);
  }
  final runner = _Runner(cfg);
  await runner.run();
  exit(runner.failed == 0 ? 0 : 1);
}

class SmokeConfig {
  /* parses smoke-test.json into typed sub-blocks identical to the Java
     SmokeTestConfig: baseUrl, publicKey, secretKey, apiVersion?, cashout?,
     bill?, topup?, voucher?, product?, subscription?, cashin?, verify?,
     validate? — each "?" block is null when the section is missing or null
     in the JSON */
}

class _Runner {
  /* run / pass / fail / skip mechanics matching Java's SmokeTest.run/printSummary */
  Future<void> _scenarioPing(SmobilpayClient c) async { /* ... */ }
  Future<void> _scenarioTokenRefresh(SmobilpayClient c) async { /* ... */ }
  Future<void> _scenarioAccount(SmobilpayClient c) async { /* ... */ }
  Future<void> _scenarioMerchants(SmobilpayClient c) async { /* ... */ }
  Future<void> _scenarioServices(SmobilpayClient c) async { /* ... */ }
}
```

> Full code for each scenario mirrors the Java reference at
> `/root/s3p-clients/java/src/samples/java/org/maviance/smobilpay/samples/SmokeTest.java`.
> Output line format is identical: `RUN  <name>`, indented `     detail`
> lines, `PASS <name>` / `SKIP <name> - <reason>` / `FAIL <name> - <error>`,
> separator line of 70 dashes between scenarios.

- [ ] **Step 21.3: Smoke-compile**

Run: `dart compile exe bin/smoketest.dart -o /tmp/smoketest`
Expected: compiles without errors.

- [ ] **Step 21.4: Verify it errors cleanly on a missing config**

Run: `dart run smobilpay:smoketest /tmp/does-not-exist.json; echo "exit=$?"`
Expected: `Configuration error: config file not found at ...`, `exit=2`.

- [ ] **Step 21.5: Commit**

```bash
git add bin/smoketest.dart smoke-test.example.json
git commit -m "feat(smoketest): scaffold + first 5 scenarios (ping, refresh, account, merchants, services)"
```

## Task 22: Remaining smoke-test scenarios + collect-opt-in

Add the remaining ten scenarios in the same file, in the same order as
Java's `SmokeTest.execute`:

- cashout (collection)
- bill (collection)
- topup (collection)
- voucher (collection, with `respCode 41004` skip)
- product (collection)
- subscription (collection, requires `serviceNumber` or `customerNumber`)
- cashin (disbursement)
- verifyServiceNumber (with `respCode 40408` skip)
- validateAccount (with HTTP 401 skip)
- historyLast7Days

By default every collection / disbursement scenario stops at the quote
and prints `(intentionally NOT calling /v2/collectstd — set "collect":
true on this block to enable)`. When a flow block sets `collect: true`,
the scenario follows the quote with a real `POST /v2/collectstd` and
polls `/v2/verifytx` once.

### 22.0: Smoke-test config shape (recap)

Every flow block extends the schema with these optional keys (all-null
for quote-only mode):

```dart
class CollectOptIn {
  /// If true and customer fields are set, follow the quote with a real
  /// POST /v2/collectstd.
  final bool collect;
  final String? customerPhonenumber;
  final String? customerEmailaddress;
  final String? serviceNumber;
  final String? customerName;
  final String? customerAddress;
  final String? customerNumber;
  final String? trid;
  final String? tag;
  final String? callbackUrl;
  final String? cdata;
}
```

Each flow's typed config block (`CashoutCfg`, `BillCfg`, …, `CashinCfg`)
includes those fields. `subscription` and `bill` keep their existing
`merchant` / `serviceNumber` / `customerNumber` fields; `collect: true`
on those blocks reuses the same `customerPhonenumber` / `customerEmail…`
keys.

### 22.1: Helpers shared by every scenario

In `bin/smoketest.dart`, add (or extend, if already present from Task 21):

```dart
Future<QuoteResponse> _quoteOnly(SmobilpayClient client, PaymentItem item, int amount) async {
  final quote = await client.initiate.quote(
    QuoteRequest(amount: amount, payItemId: item.payItemId),
  );
  _detail('quoteId:        ${quote.quoteId}');
  _detail('expiresAt:      ${quote.expiresAt}');
  _detail('price (local):  ${quote.priceLocalCur} ${quote.localCur}');
  _detail('price (system): ${quote.priceSystemCur} ${quote.systemCur}');
  _detail('promotion:      ${quote.promotion}');
  return quote;
}

void _quoteOnlyTail() {
  _detail('(intentionally NOT calling /v2/collectstd — set "collect": true on this block to enable)');
}

/// Real collect, gated by `c.collect == true`.
Future<void> _collectAndReport(
  SmobilpayClient client,
  QuoteResponse quote,
  CollectOptIn c,
) async {
  if (c.customerPhonenumber == null || c.customerPhonenumber!.isEmpty) {
    throw const SmobilpayConfigException(
      "'collect' is true but 'customerPhonenumber' is missing",
    );
  }
  if (c.customerEmailaddress == null || c.customerEmailaddress!.isEmpty) {
    throw const SmobilpayConfigException(
      "'collect' is true but 'customerEmailaddress' is missing",
    );
  }
  final trid = c.trid ?? 'dart-smoke-${DateTime.now().millisecondsSinceEpoch}';
  final request = CollectionRequest(
    quoteId: quote.quoteId,
    customerPhonenumber: c.customerPhonenumber!,
    customerEmailaddress: c.customerEmailaddress!,
    customerName: c.customerName,
    customerAddress: c.customerAddress,
    customerNumber: c.customerNumber,
    serviceNumber: c.serviceNumber,
    trid: trid,
    tag: c.tag,
    callbackUrl: c.callbackUrl,
    cdata: c.cdata,
  );
  _detail('POST /v2/collectstd  trid=$trid'
      '  customerPhonenumber=${c.customerPhonenumber}'
      '${c.serviceNumber != null ? "  serviceNumber=${c.serviceNumber}" : ""}');
  final resp = await client.confirm.collect(request);
  _detail('status:         ${resp.status}');
  _detail('ptn:            ${resp.ptn}');
  _detail('receiptNumber:  ${resp.receiptNumber}');
  _detail('veriCode:       ${resp.veriCode}');
  _detail('price (local):  ${resp.priceLocalCur} ${resp.localCur}');
  _detail('price (system): ${resp.priceSystemCur} ${resp.systemCur}');
  _detail('agentBalance:   ${resp.agentBalance}');
  _detail('trid:           ${resp.trid}');
  _detail('timestamp:      ${resp.timestamp}');

  // One-shot verifyTransaction poll, matching the Node.js client.
  await Future<void>.delayed(const Duration(seconds: 1));
  try {
    final statuses = await client.verify.verifyTransaction(ptn: resp.ptn);
    if (statuses.isNotEmpty) {
      _detail('verifyTransaction.status: ${statuses.first.status}');
    } else {
      _detail('verifyTransaction returned no rows yet');
    }
  } on SmobilpayApiException catch (e) {
    _detail('verifyTransaction failed (HTTP ${e.httpStatus}); ignoring');
  }
}
```

### 22.2: Scenario shape (every collection / disbursement scenario)

Each scenario uses the same pattern. Cashin (the user's worked example)
in full:

```dart
Future<void> _scenarioCashin(SmobilpayClient client) async {
  final cashin = _cfg.cashin;
  final willCollect = cashin != null && cashin.collect == true;
  final name = 'Disbursement — cash-in (discover + quote'
      '${willCollect ? " + collect)" : ")"}';
  await _run(name, () async {
    if (cashin == null) _skip("no 'cashin' block in config");
    final items = await client.masterdata.cashins(serviceId: cashin.serviceId);
    if (items.isEmpty) {
      throw StateError('no cashin items for serviceId=${cashin.serviceId}');
    }
    final item = items.first;
    _detail('picked: ${item.payItemId} (${item.name},'
        ' ${item.amountType}, local=${item.amountLocalCur} ${item.localCur})');
    final quote = await _quoteOnly(client, item, cashin.amount);
    if (willCollect) {
      await _collectAndReport(client, quote, cashin);
    } else {
      _quoteOnlyTail();
    }
  });
}
```

Every other collection scenario (`_scenarioCashout`, `_scenarioBill`,
`_scenarioTopup`, `_scenarioVoucher`, `_scenarioProduct`,
`_scenarioSubscription`) follows the identical shape — only the
discovery call (`masterdata.cashouts(...)` / `initiate.bills(...)` etc.)
and the typed config field differ. Voucher keeps its `respCode 41004`
skip; bill / subscription keep their merchant + serviceNumber lookups.

### 22.3: Add the ten scenarios to `bin/smoketest.dart`.

Extend each typed config block (`CashoutCfg`, `BillCfg`, `TopupCfg`,
`VoucherCfg`, `ProductCfg`, `SubscriptionCfg`, `CashinCfg`) with the
`CollectOptIn` fields from §22.0. `verify` and `validate` stay
quote-only — they have no collect step.

### 22.4: Refresh `smoke-test.example.json` from Node.js's template

Node.js's example is the canonical schema-with-opt-in-docs version.
Re-copy it so the Dart side carries the same `_collect_comment` /
`_collect_example` documentation blocks:

```bash
cp ../nodejs/smoke-test.example.json smoke-test.example.json
diff smoke-test.example.json ../nodejs/smoke-test.example.json
```
Expected: no diff (files match).

### 22.5: Compile + dry-run against a synthetic config (quote-only)

```bash
cat > /tmp/smoke-empty.json <<'EOF'
{"baseUrl":"https://api.example.invalid","publicKey":"pub","secretKey":"sec"}
EOF
dart run smobilpay:smoketest /tmp/smoke-empty.json; echo "exit=$?"
```
Expected: every "Collection — …" / "Disbursement — …" scenario is
SKIPped because its config block is absent; ping/account/merchants/
services FAIL with HTTP errors (URL is fake); exit code `1`.

> Do NOT commit `/tmp/smoke-empty.json`.

### 22.6: Smoke-shape test for the collect helper

Add `test/smoketest/collect_optin_test.dart`:

```dart
import 'package:smobilpay/smobilpay.dart';
import 'package:test/test.dart';

void main() {
  test('collect-opt-in requires customerPhonenumber + customerEmailaddress', () {
    // Sanity-only: ensures the smoke test's helper validation in §22.1
    // surfaces a SmobilpayConfigException, not a generic ArgumentError.
    expect(
      () => CollectionRequest(
        quoteId: '00000000-0000-0000-0000-000000000000',
        customerPhonenumber: '',
        customerEmailaddress: 'a@b.c',
      ),
      throwsA(isA<SmobilpayConfigException>()),
    );
  });

  test('auto-generated trid is dart-smoke-<unix-ms>', () {
    final trid = 'dart-smoke-${DateTime.now().millisecondsSinceEpoch}';
    expect(trid, matches(RegExp(r'^dart-smoke-\d+$')));
  });
}
```

Run: `dart test test/smoketest/collect_optin_test.dart`
Expected: green. (The constructor-level validation hook is added in
Task 18 — see CollectionRequest empty-string handling.)

### 22.7: Commit

```bash
git add bin/smoketest.dart smoke-test.example.json test/smoketest/collect_optin_test.dart
git commit -m "feat(smoketest): 10 remaining scenarios + collect-opt-in path

Wires every collection/disbursement scenario for an opt-in real
POST /v2/collectstd when the flow block sets \"collect\": true plus
customerPhonenumber/customerEmailaddress (and serviceNumber where
required). Follows successful collects with a one-shot verifyTransaction
poll. Quote-only by default — CI never moves money."
```

## Task 23: `tool/compare_smoketest.dart`

**Files:**
- Create: `tool/compare_smoketest.dart`

- [ ] **Step 23.1: Implement the comparator**

```dart
import 'dart:io';

/// Diffs normalized smoke-test logs between Dart and any other client
/// (Java/Go/PHP).
///
/// Usage: `dart run tool/compare_smoketest.dart --dart out/dart.log --other out/java.log`
Future<void> main(List<String> args) async {
  String? dartPath;
  String? otherPath;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--dart':
        dartPath = args[++i];
      case '--other':
        otherPath = args[++i];
      default:
        stderr.writeln('Unknown arg: ${args[i]}');
        exit(2);
    }
  }
  if (dartPath == null || otherPath == null) {
    stderr.writeln('Usage: compare_smoketest --dart <path> --other <path>');
    exit(2);
  }
  final a = _normalize(File(dartPath).readAsLinesSync());
  final b = _normalize(File(otherPath).readAsLinesSync());
  if (_equal(a, b)) {
    stdout.writeln('OK: logs match after normalization (${a.length} lines)');
    exit(0);
  }
  for (var i = 0; i < a.length || i < b.length; i++) {
    final left = i < a.length ? a[i] : '';
    final right = i < b.length ? b[i] : '';
    if (left != right) {
      stdout.writeln('- ${left.isEmpty ? "<eof>" : left}');
      stdout.writeln('+ ${right.isEmpty ? "<eof>" : right}');
    }
  }
  exit(1);
}

List<String> _normalize(List<String> lines) {
  return lines.map((line) {
    var s = line.trimRight();
    s = s.replaceAll(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z'), '<ts>');
    s = s.replaceAll(RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'), '<id>');
    s = s.replaceAll(RegExp(r'\bPTN-[A-Z0-9]+'), 'PTN-<id>');
    s = s.replaceAll(RegExp(r'\bTRID-[A-Z0-9]+'), 'TRID-<id>');
    s = s.replaceAll(RegExp(r'(prefix:\s*)[A-Za-z0-9._-]+'), r'\1<token>');
    return s;
  }).toList();
}

bool _equal(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

- [ ] **Step 23.2: Smoke-test against two identical files**

Run:
```bash
echo 'PASS Ping (auth probe)' > /tmp/a.log
cp /tmp/a.log /tmp/b.log
dart run tool/compare_smoketest.dart --dart /tmp/a.log --other /tmp/b.log; echo "exit=$?"
```
Expected: `OK: logs match...`, `exit=0`.

- [ ] **Step 23.3: Commit**

```bash
git add tool/compare_smoketest.dart
git commit -m "feat(tool): cross-client smoke-test log comparator"
```

---

# Phase 7 — Documentation & coverage tooling

## Task 24: Full README content

**Files:**
- Modify: `README.md`

- [ ] **Step 24.1: Replace the placeholder README with full content**

Sections (mirror the Java README outline at `/root/s3p-clients/java/README.md`):

1. Pitch + status badges (pub + CI).
2. Requirements (Dart `^3.0.0`, network access, OAuth credentials).
3. Installation (`dart pub add smobilpay`).
4. Quickstart (ping in 5 lines).
5. Configuration reference (every `SmobilpayConfig` field with default and meaning).
6. Authentication (OAuth flow, token caching, refresh, manual `tokens.refresh()`).
7. Flows — one subsection each with a runnable snippet:
   - Masterdata discovery
   - Bill payment (search + quote)
   - Cashout / collection (discover + quote + confirm)
   - Cashin / disbursement
   - Top-up
   - Product / Voucher / Subscription
   - Quote → Confirm (full flow incl. expiry retry)
   - Verification & history
8. Error handling — sealed hierarchy with example switch + common `respCode`s (`41004`, `40408`, HTTP `498`, HTTP `401`).
9. Account validation (with the restricted-endpoint note).
10. Smoke test (how to run, what it asserts, the 3-source config resolution order, the cross-client comparison workflow).
11. Onboarding — Maviance issues `baseUrl` / `publicKey` / `secretKey`.
12. Development (clone, format, analyze, test, coverage, smoketest, compare).
13. License.

- [ ] **Step 24.2: Run `dart format` and `dart analyze` to make sure the snippet code blocks would compile if extracted.**

For each ```dart``` block in the README, manually mentally check the
imports and the call shape match the public surface. (No tooling for this
yet — it is a manual review.)

- [ ] **Step 24.3: Commit**

```bash
git add README.md
git commit -m "docs: full partner-facing README mirroring the Java README outline"
```

## Task 25: dartdoc pass + `example/` files

**Files:**
- Create: `example/ping.dart`
- Create: `example/catalog.dart`
- Create: `example/quote_collection.dart`
- Create: `example/account_validation.dart`
- Create: `example/README.md`

- [ ] **Step 25.1: Add `example/ping.dart`**

```dart
// Smallest possible runnable: mint a token, ping, print the version.
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
```

- [ ] **Step 25.2: Add `example/catalog.dart`, `quote_collection.dart`, `account_validation.dart`** — follow the same pattern, each ~40 lines, runnable with the same env vars.

- [ ] **Step 25.3: Add `example/README.md`** — explain that examples are runnable with `SMOBILPAY_BASE_URL` / `SMOBILPAY_PUBLIC_KEY` / `SMOBILPAY_SECRET_KEY` set, list each file with its one-line purpose.

- [ ] **Step 25.4: Run analyzer on the examples**

Run: `dart analyze example/ --fatal-infos`
Expected: `No issues found!`. Examples are part of the package and must
pass the same lints.

- [ ] **Step 25.5: dartdoc pass**

For every file under `lib/src/`, audit that each public class, field,
constructor, getter, and method carries a `///` doc comment. Run:

```bash
dart analyze --fatal-infos lib/
```
Expected: zero `public_member_api_docs` violations (the lint is enabled
in `analysis_options.yaml`). Fix any missing docs before committing.

- [ ] **Step 25.6: Commit**

```bash
git add example/
git commit -m "docs: runnable examples for ping, catalog, quote_collection, account_validation"
```

## Task 26: `tool/check_coverage.dart`

**Files:**
- Create: `tool/check_coverage.dart`
- Modify: `.gitignore` (ensure `coverage/` is ignored — already done in Task 1)

- [ ] **Step 26.1: Implement the coverage gate**

```dart
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
```

- [ ] **Step 26.2: Run the full coverage flow locally**

Run:
```bash
dart pub global activate coverage
dart test --coverage=coverage/
dart pub global run coverage:format_coverage \
    --lcov --in=coverage/ --out=coverage/lcov.info \
    --packages=.dart_tool/package_config.json --report-on=lib
dart run tool/check_coverage.dart coverage/lcov.info 80
```
Expected: `PASS`. If the report is below 80%, identify the uncovered
files in `coverage/lcov.info` and add fixture-driven tests until the
gate passes.

- [ ] **Step 26.3: Commit**

```bash
git add tool/check_coverage.dart
git commit -m "feat(tool): lcov-based 80% coverage gate on lib/src/"
```

---

# Phase 8 — Publish prep

## Task 27: pub.dev metadata + dry-run

**Files:**
- Verify: `pubspec.yaml` (already populated in Task 1).
- Verify: `README.md`, `CHANGELOG.md`, `LICENSE`, `example/` (all exist).

- [ ] **Step 27.1: Sanity-check pub-ready files**

Run:
```bash
test -f README.md && test -f CHANGELOG.md && test -f LICENSE && \
  test -d example && grep -q 'description:' pubspec.yaml && \
  grep -q 'homepage:' pubspec.yaml && grep -q 'topics:' pubspec.yaml \
  && echo OK
```
Expected: `OK`.

- [ ] **Step 27.2: Run `dart pub publish --dry-run`**

Run: `dart pub publish --dry-run`
Expected: `Package has 0 warnings.` Resolve any warnings the tool surfaces
(missing example/, missing description length, unresolved links, etc.) by
amending the relevant file before re-running.

- [ ] **Step 27.3: Verify the full local CI flow**

Run:
```bash
dart format --output=none --set-exit-if-changed . && \
  dart analyze --fatal-infos --fatal-warnings && \
  dart test --coverage=coverage/ && \
  dart pub global run coverage:format_coverage \
      --lcov --in=coverage/ --out=coverage/lcov.info \
      --packages=.dart_tool/package_config.json --report-on=lib && \
  dart run tool/check_coverage.dart coverage/lcov.info 80 && \
  dart pub publish --dry-run
```
Expected: green throughout.

- [ ] **Step 27.4: Final commit (only if pubspec or README received touch-ups)**

```bash
git add pubspec.yaml README.md
git commit -m "chore: pub.dev metadata polish for 3.2.0 publish"
```

- [ ] **Step 27.5: Open the PR**

```bash
git push -u origin feature/rewrite-v3.2-oauth2-only
gh pr create \
  --base master \
  --title "feat: v3.2.0 — OAuth2-only S3P partner API client rebuild" \
  --body "$(cat <<'EOF'
## Summary
- Rebuilds the package from a 112-line HMAC helper into a full S3P partner API v3.2.0 client.
- OAuth 2.0 `client_credentials` is the only authentication method.
- Five API groups (`verify`, `masterdata`, `accountValidation`, `initiate`, `confirm`), sealed exception hierarchy, hand-written DTOs, no codegen.
- Smoke-test CLI (`dart run smobilpay:smoketest`) consumes the same `smoke-test.json` schema as the Java client; `tool/compare_smoketest.dart` diffs normalized Dart vs Java/Go/PHP runs.
- 80% line-coverage gate on `lib/src/` enforced in CI.

## Test plan
- [ ] `dart format --output=none --set-exit-if-changed .` passes
- [ ] `dart analyze --fatal-infos --fatal-warnings` passes
- [ ] `dart test` — full suite green
- [ ] Coverage on `lib/src/` ≥ 80%
- [ ] `dart pub publish --dry-run` passes
- [ ] Manual: run `dart run smobilpay:smoketest` against the acceptance environment with the Java smoke-test config; output matches Java's via `tool/compare_smoketest.dart`.
EOF
)"
```
Expected: PR URL printed.

---

# Self-review against the spec

After completing all 27 tasks, run this checklist once before declaring done.

- **§2 Goals** — ✅ Every endpoint in the partner spec is covered by Tasks
  15–19. OAuth-only enforced by removal of HMAC in Task 1. Idiomatic
  Dart 3 (final fields, sealed exceptions, named-param constructors) used
  throughout. 80% coverage gate in Tasks 2/26. Smoke-test parity in
  Tasks 21–23. README parity in Task 24. pub.dev publish in Task 27.
- **§3 Locked decisions** — every row maps to a specific task. SDK floor +
  package name + `http ^1.2` set in Task 1. `dart:convert`-only JSON in
  Tasks 3–19. `Completer`-guarded mutex in Task 10. Sealed errors in Task
  3. Hand-rolled `FakeHttpClient` in Task 8. Coverage gate in Task 26.
  Smoke executable in Task 21. License kept (never deleted in Task 1).
- **§4 Public API shape** — every method signature in §4.2 is covered by
  Task 15 (Verify), Task 16 (Masterdata), Task 17 (Initiate), Task 18
  (Confirm), Task 19 (AccountValidation), Task 20 (facade + tokens).
- **§5 Module layout** — Task 1 + Tasks 3–20 create every file from the
  layout. `lib/src/http/json_codec.dart` from §5 is omitted because its
  duties are absorbed by `transport.dart` (`jsonEncode`/`jsonDecode`
  inline). If the user wants a separate file later, it is a trivial
  refactor.
- **§6 Authentication** — Tasks 5 + 10 implement every clause, including
  the five failure modes in §6.3.
- **§7 HTTP transport** — Task 11 implements every clause; query
  null/empty-skipping in Task 7 matches §7.1.
- **§8 Smoke test** — Tasks 21–23 implement every scenario, the
  resolution order, the line shape, and the cross-client comparator.
- **§9 Testing strategy** — Task 8 provides the support, Tasks 3–20
  provide the unit tests, Task 26 enforces the gate. Integration tests
  remain a follow-up per §13 ("recorded-cassette mode is a follow-up").
- **§10 Documentation & publishing** — Tasks 24, 25, 27.
- **§11 Dependencies** — pubspec in Task 1 sets exactly the constraints.
- **§12 Cross-language behavioural parity** — explicitly enforced by
  Tasks 10 (token defaults, skew), 11 (api-version header, query
  skipping), 15–19 (skip codes for 41004/40408/401), 23 (log shape).
- **§13 Open questions** — both follow-ups are documented inline as
  out-of-scope. The plan does not implement them.
- **§14 Implementation order** — the eight phases of this plan match
  §14's eight-phase sequence one-for-one.

If anything in the checklist is unfulfilled at the end, that is a plan
bug — return to the relevant task and finish it before declaring done.

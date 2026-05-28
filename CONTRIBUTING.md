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

## Commit style

[Conventional Commits](https://www.conventionalcommits.org/) — `feat:`,
`fix:`, `docs:`, `refactor:`, `test:`, `chore:`.

## Release checklist

1. Bump `version:` in `pubspec.yaml`.
2. Add a new section to `CHANGELOG.md`.
3. Run `dart pub publish --dry-run`.
4. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.

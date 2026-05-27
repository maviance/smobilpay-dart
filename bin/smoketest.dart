// bin/smoketest.dart
//
// Smoke-test harness for the Smobilpay Dart client against a real partner
// environment.
//
// Configuration is resolved in this order:
//   1. First CLI argument, if present.
//   2. SMOBILPAY_SMOKE_CONFIG env var, if set.
//   3. ./smoke-test.json in the current working directory.
//
// Exit codes:
//   0 — all non-skipped scenarios passed
//   1 — at least one scenario failed
//   2 — configuration error before the client started
//
// Run:
//   dart run smobilpay:smoketest [path/to/smoke-test.json]
//
// See smoke-test.example.json for a fully-populated template.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:smobilpay/smobilpay.dart';

const _sep =
    '----------------------------------------------------------------------';
const _bannerLine =
    '======================================================================';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  _SmokeConfig cfg;
  try {
    cfg = _SmokeConfig.load(args);
    cfg.validateRequired();
  } on _ConfigError catch (e) {
    stderr.writeln('Configuration error: ${e.message}');
    exit(2);
  }

  final clientConfig = SmobilpayConfig(
    baseUrl: Uri.parse(cfg.baseUrl!),
    publicKey: cfg.publicKey!,
    secretKey: cfg.secretKey!,
    apiVersion: cfg.apiVersion ?? SmobilpayConfig.defaultApiVersion,
  );

  _printBanner(
    'Smobilpay smoke test  —  baseUrl=${_redact(clientConfig.baseUrl.toString())}, '
    'apiVersion=${clientConfig.apiVersion}, '
    'publicKey=${_redactKey(clientConfig.publicKey)}',
  );

  final client = SmobilpayClient(config: clientConfig);
  final runner = _Runner(cfg);
  try {
    await runner._scenarioPing(client);
    await runner._scenarioTokenRefresh(client);
    await runner._scenarioAccount(client);
    await runner._scenarioMerchants(client);
    await runner._scenarioServices(client);
    // Task 22 will append: cashout, bill, topup, voucher, product,
    // subscription, cashin, verifyServiceNumber, validateAccount,
    // historyByDateRange.
  } finally {
    client.close();
  }

  runner._printSummary();
  exit(runner.failed == 0 ? 0 : 1);
}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/// Typed representation of the smoke-test JSON config file.
///
/// All per-flow blocks ([cashout], [bill], etc.) are optional. An absent
/// block causes the corresponding scenario to be skipped.
class _SmokeConfig {
  _SmokeConfig({
    this.baseUrl,
    this.publicKey,
    this.secretKey,
    this.apiVersion,
    this.cashout,
    this.bill,
    this.topup,
    this.voucher,
    this.product,
    this.subscription,
    this.cashin,
    this.verify,
    this.validate,
  });

  factory _SmokeConfig.fromJson(Map<String, dynamic> json) => _SmokeConfig(
        baseUrl: json['baseUrl'] as String?,
        publicKey: json['publicKey'] as String?,
        secretKey: json['secretKey'] as String?,
        apiVersion: json['apiVersion'] as String?,
        cashout: json['cashout'] is Map<String, dynamic>
            ? _CashoutCfg.fromJson(json['cashout'] as Map<String, dynamic>)
            : null,
        bill: json['bill'] is Map<String, dynamic>
            ? _BillCfg.fromJson(json['bill'] as Map<String, dynamic>)
            : null,
        topup: json['topup'] is Map<String, dynamic>
            ? _TopupCfg.fromJson(json['topup'] as Map<String, dynamic>)
            : null,
        voucher: json['voucher'] is Map<String, dynamic>
            ? _VoucherCfg.fromJson(json['voucher'] as Map<String, dynamic>)
            : null,
        product: json['product'] is Map<String, dynamic>
            ? _ProductCfg.fromJson(json['product'] as Map<String, dynamic>)
            : null,
        subscription: json['subscription'] is Map<String, dynamic>
            ? _SubscriptionCfg.fromJson(
                json['subscription'] as Map<String, dynamic>)
            : null,
        cashin: json['cashin'] is Map<String, dynamic>
            ? _CashinCfg.fromJson(json['cashin'] as Map<String, dynamic>)
            : null,
        verify: json['verify'] is Map<String, dynamic>
            ? _VerifyCfg.fromJson(json['verify'] as Map<String, dynamic>)
            : null,
        validate: json['validate'] is Map<String, dynamic>
            ? _ValidateCfg.fromJson(json['validate'] as Map<String, dynamic>)
            : null,
      );

  /// Loads config from the CLI args / env var / default path.
  static _SmokeConfig load(List<String> args) {
    final path = _resolvePath(args);
    final file = File(path);
    if (!file.existsSync()) {
      throw _ConfigError(
        'config file not found at ${file.absolute.path}. '
        'Pass a path as the first argument, set SMOBILPAY_SMOKE_CONFIG, '
        'or create ./smoke-test.json (see smoke-test.example.json).',
      );
    }
    final String raw;
    try {
      raw = file.readAsStringSync();
    } catch (e) {
      throw _ConfigError('could not read ${file.absolute.path}: $e');
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _SmokeConfig.fromJson(json);
    } catch (e) {
      throw _ConfigError('could not parse ${file.absolute.path}: $e');
    }
  }

  static String _resolvePath(List<String> args) {
    if (args.isNotEmpty && args[0].trim().isNotEmpty) {
      return args[0].trim();
    }
    final env = Platform.environment['SMOBILPAY_SMOKE_CONFIG'];
    if (env != null && env.trim().isNotEmpty) {
      return env.trim();
    }
    return 'smoke-test.json';
  }

  void validateRequired() {
    if (baseUrl == null || baseUrl!.isEmpty) {
      throw _ConfigError("missing required field 'baseUrl'");
    }
    if (publicKey == null || publicKey!.isEmpty) {
      throw _ConfigError("missing required field 'publicKey'");
    }
    if (secretKey == null || secretKey!.isEmpty) {
      throw _ConfigError("missing required field 'secretKey'");
    }
  }

  final String? baseUrl;
  final String? publicKey;
  final String? secretKey;
  final String? apiVersion;

  final _CashoutCfg? cashout;
  final _BillCfg? bill;
  final _TopupCfg? topup;
  final _VoucherCfg? voucher;
  final _ProductCfg? product;
  final _SubscriptionCfg? subscription;
  final _CashinCfg? cashin;
  final _VerifyCfg? verify;
  final _ValidateCfg? validate;
}

class _CashoutCfg {
  _CashoutCfg({required this.serviceId, required this.amount});
  factory _CashoutCfg.fromJson(Map<String, dynamic> j) => _CashoutCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
      );
  final int serviceId;
  final int amount;
}

class _BillCfg {
  _BillCfg(
      {required this.merchant,
      required this.serviceId,
      required this.serviceNumber});
  factory _BillCfg.fromJson(Map<String, dynamic> j) => _BillCfg(
        merchant: j['merchant'] as String,
        serviceId: (j['serviceId'] as num).toInt(),
        serviceNumber: j['serviceNumber'] as String,
      );
  final String merchant;
  final int serviceId;
  final String serviceNumber;
}

class _TopupCfg {
  _TopupCfg({required this.serviceId, required this.amount});
  factory _TopupCfg.fromJson(Map<String, dynamic> j) => _TopupCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
      );
  final int serviceId;
  final int amount;
}

class _VoucherCfg {
  _VoucherCfg({required this.serviceId, this.amount});
  factory _VoucherCfg.fromJson(Map<String, dynamic> j) => _VoucherCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: j['amount'] != null ? (j['amount'] as num).toInt() : null,
      );
  final int serviceId;
  final int? amount;
}

class _ProductCfg {
  _ProductCfg({required this.serviceId, this.amount});
  factory _ProductCfg.fromJson(Map<String, dynamic> j) => _ProductCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: j['amount'] != null ? (j['amount'] as num).toInt() : null,
      );
  final int serviceId;
  final int? amount;
}

class _SubscriptionCfg {
  _SubscriptionCfg({
    required this.merchant,
    required this.serviceId,
    this.serviceNumber,
    this.customerNumber,
    this.amount,
  });
  factory _SubscriptionCfg.fromJson(Map<String, dynamic> j) => _SubscriptionCfg(
        merchant: j['merchant'] as String,
        serviceId: (j['serviceId'] as num).toInt(),
        serviceNumber: j['serviceNumber'] as String?,
        customerNumber: j['customerNumber'] as String?,
        amount: j['amount'] != null ? (j['amount'] as num).toInt() : null,
      );
  final String merchant;
  final int serviceId;
  final String? serviceNumber;
  final String? customerNumber;
  final int? amount;
}

class _CashinCfg {
  _CashinCfg({
    required this.serviceId,
    required this.amount,
    this.collect = false,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.serviceNumber,
  });
  factory _CashinCfg.fromJson(Map<String, dynamic> j) => _CashinCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        collect: j['collect'] as bool? ?? false,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        serviceNumber: j['serviceNumber'] as String?,
      );
  final int serviceId;
  final int amount;
  final bool collect;
  final String? customerPhonenumber;
  final String? customerEmailaddress;
  final String? serviceNumber;
}

class _VerifyCfg {
  _VerifyCfg(
      {required this.merchant,
      required this.serviceId,
      required this.serviceNumber});
  factory _VerifyCfg.fromJson(Map<String, dynamic> j) => _VerifyCfg(
        merchant: j['merchant'] as String,
        serviceId: (j['serviceId'] as num).toInt(),
        serviceNumber: j['serviceNumber'] as String,
      );
  final String merchant;
  final int serviceId;
  final String serviceNumber;
}

class _ValidateCfg {
  _ValidateCfg({required this.destination, required this.serviceId});
  factory _ValidateCfg.fromJson(Map<String, dynamic> j) => _ValidateCfg(
        destination: j['destination'] as String,
        serviceId: (j['serviceId'] as num).toInt(),
      );
  final String destination;
  final int serviceId;
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

class _Runner {
  _Runner(this._cfg);

  // ignore: unused_field
  final _SmokeConfig _cfg;

  int passed = 0;
  int failed = 0;
  int skipped = 0;

  // --- Scenarios (Task 21: first 5) ----------------------------------------

  Future<void> _scenarioPing(SmobilpayClient client) async {
    await _run('Ping (auth probe)', () async {
      final pong = await client.verify.ping();
      _require(pong.version.isNotEmpty, 'empty response');
      _detail('server time:    ${pong.time}');
      _detail('server version: ${pong.version}');
      _detail('nonce echo:     ${pong.nonce}');
      _detail('public key:     ${pong.key}');
    });
  }

  Future<void> _scenarioTokenRefresh(SmobilpayClient client) async {
    await _run('OAuth 2.0 token refresh', () async {
      final first = await client.tokens.accessToken();
      final forced = await client.tokens.refresh();
      _require(forced.isNotEmpty, 'refresh returned empty token');
      final pong = await client.verify.ping();
      _require(pong.version.isNotEmpty, 'ping after refresh returned empty');
      final firstLen = first.length < 12 ? first.length : 12;
      final forcedLen = forced.length < 12 ? forced.length : 12;
      _detail('first  bearer prefix: ${first.substring(0, firstLen)}...');
      _detail('forced bearer prefix: ${forced.substring(0, forcedLen)}...');
      _detail('identical: ${first == forced}');
    });
  }

  Future<void> _scenarioAccount(SmobilpayClient client) async {
    await _run('Account profile', () async {
      final account = await client.verify.account();
      _detail('agent:           ${account.agentName} (id=${account.agentId})');
      _detail('company:         ${account.companyName}');
      _detail('balance:         ${account.balance} ${account.currency}');
      _detail('daily limit max: ${account.limitMax}');
      _detail('limit remaining: ${account.limitRemaining}');
    });
  }

  Future<void> _scenarioMerchants(SmobilpayClient client) async {
    await _run('Merchant catalog', () async {
      final merchants = await client.masterdata.merchants();
      _detail('merchants: ${merchants.length}');
      final sample = merchants.length < 5 ? merchants.length : 5;
      for (var i = 0; i < sample; i++) {
        final m = merchants[i];
        _detail(
            '  - ${m.merchant} : ${m.name} (${m.country}, ${m.status.wireName})');
      }
      if (merchants.length > sample) {
        _detail('  ...and ${merchants.length - sample} more');
      }
    });
  }

  Future<void> _scenarioServices(SmobilpayClient client) async {
    await _run('Service catalog', () async {
      final services = await client.masterdata.services();
      _detail('services: ${services.length}');

      // Distribution by type — sorted alphabetically by wire name via
      // SplayTreeMap (equivalent to Java's TreeMap).
      final byType = SplayTreeMap<String, int>();
      for (final s in services) {
        byType.update(s.type.wireName, (v) => v + 1, ifAbsent: () => 1);
      }
      _detail('distribution by type:');
      byType.forEach((t, c) => _detail('  - $t: $c'));

      // Hints for locating rare serviceIds in the config file.
      _listServicesOfType(services, ServiceType.voucher, 'VOUCHER services');
      _listServicesOfType(
          services, ServiceType.subscription, 'SUBSCRIPTION services');
      _listVerifiableServices(services);
    });
  }

  // --- Harness mechanics ---------------------------------------------------

  Future<void> _run(String name, Future<void> Function() scenario) async {
    _line(_sep);
    _line('RUN  $name');
    try {
      await scenario();
      passed++;
      _line('PASS $name');
    } on _SkipException catch (e) {
      skipped++;
      _line('SKIP $name - ${e.message}');
    } on SmobilpayAuthException catch (e) {
      failed++;
      final errPart = e.oauthError != null ? ', error=${e.oauthError}' : '';
      _line(
          'FAIL $name - auth error (HTTP ${e.httpStatus}$errPart): ${e.message}');
    } on SmobilpayApiException catch (e) {
      failed++;
      _line('FAIL $name - API error (HTTP ${e.httpStatus})');
      final err = e.error;
      if (err != null) {
        _detail('respCode: ${err.respCode}');
        _detail('devMsg:   ${err.devMsg}');
        if (err.usrMsg != null) _detail('usrMsg:   ${err.usrMsg}');
        if (err.link != null) _detail('link:     ${err.link}');
      }
    } catch (e) {
      failed++;
      _line('FAIL $name - ${e.runtimeType}: $e');
    }
  }

  void _printSummary() {
    _line(_sep);
    _line('Summary: $passed passed, $skipped skipped, $failed failed');
    _line(_sep);
  }

  // --- Helpers --------------------------------------------------------------

  void _detail(String text) => _line('     $text');

  void _listServicesOfType(
      List<Service> services, ServiceType type, String label) {
    final matches = services.where((s) => s.type == type).toList();
    if (matches.isEmpty) return;
    _detail('$label:');
    for (final s in matches) {
      _detail(
          '  - serviceId=${s.serviceId} merchant=${s.merchant} title=${s.title}');
    }
  }

  void _listVerifiableServices(List<Service> services) {
    final matches = services.where((s) => s.isVerifiable).toList();
    if (matches.isEmpty) return;
    _detail(
        "verifiable services (isVerifiable=true) — candidates for the 'verify' block:");
    for (final s in matches) {
      _detail(
          '  - serviceId=${s.serviceId} merchant=${s.merchant} title=${s.title}');
    }
  }
}

// ---------------------------------------------------------------------------
// Internal exceptions
// ---------------------------------------------------------------------------

class _SkipException implements Exception {
  _SkipException(this.message);
  final String message;
}

class _ConfigError implements Exception {
  _ConfigError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

void _require(bool ok, String message) {
  if (!ok) throw StateError(message);
}

// ignore: unused_element
void _skip(String reason) => throw _SkipException(reason);

void _line(String s) => stdout.writeln(s);

void _printBanner(String message) {
  _line('');
  _line(_bannerLine);
  _line(message);
  _line(_bannerLine);
}

/// Strips a trailing `/` from a URL string.
String _redact(String s) => s.endsWith('/') ? s.substring(0, s.length - 1) : s;

/// Shows the first 4 and last 2 characters of a key, masking the rest.
String _redactKey(String key) {
  if (key.length <= 4) return '****';
  return '${key.substring(0, 4)}...${key.substring(key.length - 2)}';
}

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
    await runner._scenarioCashout(client); // collection
    await runner._scenarioBill(client);
    await runner._scenarioTopup(client);
    await runner._scenarioVoucher(client);
    await runner._scenarioProduct(client);
    await runner._scenarioSubscription(client);
    await runner._scenarioCashin(client); // disbursement
    await runner._scenarioVerifyServiceNumber(client);
    await runner._scenarioValidateAccount(client);
    await runner._scenarioHistoryLast7Days(client);
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

// ---------------------------------------------------------------------------
// Common interface for flow blocks that can opt into a real collect.
// ---------------------------------------------------------------------------

/// Common interface across every flow block that can opt into a real collect.
abstract class _CollectFields {
  bool? get collect;
  String? get customerPhonenumber;
  String? get customerEmailaddress;
  String? get serviceNumber;
  String? get customerName;
  String? get customerAddress;
  String? get customerNumber;
  String? get trid;
  String? get tag;
  String? get callbackUrl;
  String? get cdata;
}

// ---------------------------------------------------------------------------
// Per-flow config classes
// ---------------------------------------------------------------------------

class _CashoutCfg implements _CollectFields {
  _CashoutCfg({
    required this.serviceId,
    required this.amount,
    this.collect,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.serviceNumber,
    this.customerName,
    this.customerAddress,
    this.customerNumber,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  });
  factory _CashoutCfg.fromJson(Map<String, dynamic> j) => _CashoutCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        collect: j['collect'] as bool?,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        serviceNumber: j['serviceNumber'] as String?,
        customerName: j['customerName'] as String?,
        customerAddress: j['customerAddress'] as String?,
        customerNumber: j['customerNumber'] as String?,
        trid: j['trid'] as String?,
        tag: j['tag'] as String?,
        callbackUrl: j['callbackUrl'] as String?,
        cdata: j['cdata'] as String?,
      );
  final int serviceId;
  final int amount;
  @override
  final bool? collect;
  @override
  final String? customerPhonenumber;
  @override
  final String? customerEmailaddress;
  @override
  final String? serviceNumber;
  @override
  final String? customerName;
  @override
  final String? customerAddress;
  @override
  final String? customerNumber;
  @override
  final String? trid;
  @override
  final String? tag;
  @override
  final String? callbackUrl;
  @override
  final String? cdata;
}

class _BillCfg implements _CollectFields {
  _BillCfg({
    required this.merchant,
    required this.serviceId,
    required this.serviceNumber,
    this.collect,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.customerName,
    this.customerAddress,
    this.customerNumber,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  });
  factory _BillCfg.fromJson(Map<String, dynamic> j) => _BillCfg(
        merchant: j['merchant'] as String,
        serviceId: (j['serviceId'] as num).toInt(),
        serviceNumber: j['serviceNumber'] as String,
        collect: j['collect'] as bool?,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        customerName: j['customerName'] as String?,
        customerAddress: j['customerAddress'] as String?,
        customerNumber: j['customerNumber'] as String?,
        trid: j['trid'] as String?,
        tag: j['tag'] as String?,
        callbackUrl: j['callbackUrl'] as String?,
        cdata: j['cdata'] as String?,
      );
  final String merchant;
  final int serviceId;
  // serviceNumber is both a required lookup field AND an optional collect
  // pass-through field — it satisfies _CollectFields.serviceNumber directly.
  @override
  final String serviceNumber;
  @override
  final bool? collect;
  @override
  final String? customerPhonenumber;
  @override
  final String? customerEmailaddress;
  @override
  final String? customerName;
  @override
  final String? customerAddress;
  @override
  final String? customerNumber;
  @override
  final String? trid;
  @override
  final String? tag;
  @override
  final String? callbackUrl;
  @override
  final String? cdata;
}

class _TopupCfg implements _CollectFields {
  _TopupCfg({
    required this.serviceId,
    required this.amount,
    this.collect,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.serviceNumber,
    this.customerName,
    this.customerAddress,
    this.customerNumber,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  });
  factory _TopupCfg.fromJson(Map<String, dynamic> j) => _TopupCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        collect: j['collect'] as bool?,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        serviceNumber: j['serviceNumber'] as String?,
        customerName: j['customerName'] as String?,
        customerAddress: j['customerAddress'] as String?,
        customerNumber: j['customerNumber'] as String?,
        trid: j['trid'] as String?,
        tag: j['tag'] as String?,
        callbackUrl: j['callbackUrl'] as String?,
        cdata: j['cdata'] as String?,
      );
  final int serviceId;
  final int amount;
  @override
  final bool? collect;
  @override
  final String? customerPhonenumber;
  @override
  final String? customerEmailaddress;
  @override
  final String? serviceNumber;
  @override
  final String? customerName;
  @override
  final String? customerAddress;
  @override
  final String? customerNumber;
  @override
  final String? trid;
  @override
  final String? tag;
  @override
  final String? callbackUrl;
  @override
  final String? cdata;
}

class _VoucherCfg implements _CollectFields {
  _VoucherCfg({
    required this.serviceId,
    this.amount,
    this.collect,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.serviceNumber,
    this.customerName,
    this.customerAddress,
    this.customerNumber,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  });
  factory _VoucherCfg.fromJson(Map<String, dynamic> j) => _VoucherCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: j['amount'] != null ? (j['amount'] as num).toInt() : null,
        collect: j['collect'] as bool?,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        serviceNumber: j['serviceNumber'] as String?,
        customerName: j['customerName'] as String?,
        customerAddress: j['customerAddress'] as String?,
        customerNumber: j['customerNumber'] as String?,
        trid: j['trid'] as String?,
        tag: j['tag'] as String?,
        callbackUrl: j['callbackUrl'] as String?,
        cdata: j['cdata'] as String?,
      );
  final int serviceId;
  final int? amount;
  @override
  final bool? collect;
  @override
  final String? customerPhonenumber;
  @override
  final String? customerEmailaddress;
  @override
  final String? serviceNumber;
  @override
  final String? customerName;
  @override
  final String? customerAddress;
  @override
  final String? customerNumber;
  @override
  final String? trid;
  @override
  final String? tag;
  @override
  final String? callbackUrl;
  @override
  final String? cdata;
}

class _ProductCfg implements _CollectFields {
  _ProductCfg({
    required this.serviceId,
    this.amount,
    this.collect,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.serviceNumber,
    this.customerName,
    this.customerAddress,
    this.customerNumber,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  });
  factory _ProductCfg.fromJson(Map<String, dynamic> j) => _ProductCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: j['amount'] != null ? (j['amount'] as num).toInt() : null,
        collect: j['collect'] as bool?,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        serviceNumber: j['serviceNumber'] as String?,
        customerName: j['customerName'] as String?,
        customerAddress: j['customerAddress'] as String?,
        customerNumber: j['customerNumber'] as String?,
        trid: j['trid'] as String?,
        tag: j['tag'] as String?,
        callbackUrl: j['callbackUrl'] as String?,
        cdata: j['cdata'] as String?,
      );
  final int serviceId;
  final int? amount;
  @override
  final bool? collect;
  @override
  final String? customerPhonenumber;
  @override
  final String? customerEmailaddress;
  @override
  final String? serviceNumber;
  @override
  final String? customerName;
  @override
  final String? customerAddress;
  @override
  final String? customerNumber;
  @override
  final String? trid;
  @override
  final String? tag;
  @override
  final String? callbackUrl;
  @override
  final String? cdata;
}

class _SubscriptionCfg implements _CollectFields {
  _SubscriptionCfg({
    required this.merchant,
    required this.serviceId,
    this.serviceNumber,
    this.customerNumber,
    this.amount,
    this.collect,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.customerName,
    this.customerAddress,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  });
  factory _SubscriptionCfg.fromJson(Map<String, dynamic> j) => _SubscriptionCfg(
        merchant: j['merchant'] as String,
        serviceId: (j['serviceId'] as num).toInt(),
        serviceNumber: j['serviceNumber'] as String?,
        customerNumber: j['customerNumber'] as String?,
        amount: j['amount'] != null ? (j['amount'] as num).toInt() : null,
        collect: j['collect'] as bool?,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        customerName: j['customerName'] as String?,
        customerAddress: j['customerAddress'] as String?,
        trid: j['trid'] as String?,
        tag: j['tag'] as String?,
        callbackUrl: j['callbackUrl'] as String?,
        cdata: j['cdata'] as String?,
      );
  final String merchant;
  final int serviceId;
  @override
  final String? serviceNumber;
  @override
  final String? customerNumber;
  final int? amount;
  @override
  final bool? collect;
  @override
  final String? customerPhonenumber;
  @override
  final String? customerEmailaddress;
  @override
  final String? customerName;
  @override
  final String? customerAddress;
  @override
  final String? trid;
  @override
  final String? tag;
  @override
  final String? callbackUrl;
  @override
  final String? cdata;
}

class _CashinCfg implements _CollectFields {
  _CashinCfg({
    required this.serviceId,
    required this.amount,
    this.collect,
    this.customerPhonenumber,
    this.customerEmailaddress,
    this.serviceNumber,
    this.customerName,
    this.customerAddress,
    this.customerNumber,
    this.trid,
    this.tag,
    this.callbackUrl,
    this.cdata,
  });
  factory _CashinCfg.fromJson(Map<String, dynamic> j) => _CashinCfg(
        serviceId: (j['serviceId'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        collect: j['collect'] as bool?,
        customerPhonenumber: j['customerPhonenumber'] as String?,
        customerEmailaddress: j['customerEmailaddress'] as String?,
        serviceNumber: j['serviceNumber'] as String?,
        customerName: j['customerName'] as String?,
        customerAddress: j['customerAddress'] as String?,
        customerNumber: j['customerNumber'] as String?,
        trid: j['trid'] as String?,
        tag: j['tag'] as String?,
        callbackUrl: j['callbackUrl'] as String?,
        cdata: j['cdata'] as String?,
      );
  final int serviceId;
  final int amount;
  @override
  final bool? collect;
  @override
  final String? customerPhonenumber;
  @override
  final String? customerEmailaddress;
  @override
  final String? serviceNumber;
  @override
  final String? customerName;
  @override
  final String? customerAddress;
  @override
  final String? customerNumber;
  @override
  final String? trid;
  @override
  final String? tag;
  @override
  final String? callbackUrl;
  @override
  final String? cdata;
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

  final _SmokeConfig _cfg;

  int passed = 0;
  int failed = 0;
  int skipped = 0;

  // --- Scenarios -----------------------------------------------------------

  Future<void> _scenarioPing(SmobilpayClient client) async {
    await _run('Ping (auth probe)', () async {
      final pong = await client.verify.ping();
      _require(pong.version.isNotEmpty, 'empty response');
      _dumpFields(pong.toJson(), _detail);
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
      _dumpFields(pong.toJson(), _detail);
    });
  }

  Future<void> _scenarioAccount(SmobilpayClient client) async {
    await _run('Account profile', () async {
      final account = await client.verify.account();
      _dumpFields(account.toJson(), _detail);
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
      if (merchants.isNotEmpty) {
        _detail('first merchant fields:');
        _dumpFields(merchants.first.toJson(), _detail);
      }
    });
  }

  Future<void> _scenarioServices(SmobilpayClient client) async {
    await _run('Service catalog', () async {
      final services = await client.masterdata.services();
      _detail('services: ${services.length}');

      // SplayTreeMap keeps the type distribution sorted for stable output.
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
      if (services.isNotEmpty) {
        _detail('first service fields:');
        _dumpFields(services.first.toJson(), _detail);
      }
    });
  }

  Future<void> _scenarioCashout(SmobilpayClient client) async {
    final cashout = _cfg.cashout;
    final willCollect = cashout != null && cashout.collect == true;
    final name = 'Collection — cash-out (discover + quote'
        '${willCollect ? " + collect)" : ")"}';
    await _run(name, () async {
      if (cashout == null) _skip("no 'cashout' block in config");
      final items =
          await client.masterdata.cashouts(serviceId: cashout!.serviceId);
      if (items.isEmpty) {
        throw StateError('no cashout items for serviceId=${cashout.serviceId}');
      }
      final item = items.first;
      _detail('picked: ${item.payItemId} (${item.name},'
          ' ${item.amountType}, local=${item.amountLocalCur} ${item.localCur})');
      _dumpFields(item.toJson(), _detail);
      final quote = await _quoteOnly(client, item, cashout.amount, _detail);
      if (willCollect) {
        await _collectAndReport(client, quote, cashout, _detail);
      } else {
        _quoteOnlyTail(_detail);
      }
    });
  }

  Future<void> _scenarioBill(SmobilpayClient client) async {
    final bill = _cfg.bill;
    final willCollect = bill != null && bill.collect == true;
    final name = 'Collection — bill payment (discover + quote'
        '${willCollect ? " + collect)" : ")"}';
    await _run(name, () async {
      if (bill == null) _skip("no 'bill' block in config");
      final bills = await client.initiate.bills(
        merchant: bill!.merchant,
        serviceId: bill.serviceId,
        serviceNumber: bill.serviceNumber,
      );
      if (bills.isEmpty) {
        throw StateError(
            'no bills for ${bill.merchant}/${bill.serviceId}/${bill.serviceNumber}');
      }
      final b = bills.first;
      _detail('picked: ${b.payItemId} (${b.billType},'
          ' amount=${b.amountLocalCur} ${b.localCur},'
          ' due=${b.billDueDate})');
      _dumpFields(b.toJson(), _detail);
      final amount = (b.amountLocalCur ?? 0.0).toInt();
      final quote = await _quoteOnly(client, b, amount, _detail);
      if (willCollect) {
        await _collectAndReport(client, quote, bill, _detail);
      } else {
        _quoteOnlyTail(_detail);
      }
    });
  }

  Future<void> _scenarioTopup(SmobilpayClient client) async {
    final topup = _cfg.topup;
    final willCollect = topup != null && topup.collect == true;
    final name = 'Collection — airtime top-up (discover + quote'
        '${willCollect ? " + collect)" : ")"}';
    await _run(name, () async {
      if (topup == null) _skip("no 'topup' block in config");
      final items = await client.masterdata.topups(serviceId: topup!.serviceId);
      if (items.isEmpty) {
        throw StateError('no topup items for serviceId=${topup.serviceId}');
      }
      final item = items.first;
      _detail('picked: ${item.payItemId} (${item.name},'
          ' ${item.amountType}, local=${item.amountLocalCur} ${item.localCur})');
      _dumpFields(item.toJson(), _detail);
      final quote = await _quoteOnly(client, item, topup.amount, _detail);
      if (willCollect) {
        await _collectAndReport(client, quote, topup, _detail);
      } else {
        _quoteOnlyTail(_detail);
      }
    });
  }

  Future<void> _scenarioVoucher(SmobilpayClient client) async {
    final voucher = _cfg.voucher;
    final willCollect = voucher != null && voucher.collect == true;
    final name = 'Collection — voucher purchase (discover + quote'
        '${willCollect ? " + collect)" : ")"}';
    await _run(name, () async {
      if (voucher == null) _skip("no 'voucher' block in config");
      // voucher is non-null below: _skip throws _SkipException.
      final v = voucher!;
      List<Product> items;
      try {
        items = await client.masterdata.vouchers(serviceId: v.serviceId);
      } on SmobilpayApiException catch (e) {
        if (e.error?.respCode == 41004) {
          _skip('/v2/voucher rejects serviceId=${v.serviceId}'
              ' (respCode 41004) even though the catalog labels it VOUCHER');
        }
        if (e.error == null && e.rawBody != null && e.rawBody!.isNotEmpty) {
          _detail('rawBody:  ${e.rawBody}');
        }
        rethrow;
      }
      if (items.isEmpty) {
        throw StateError('no vouchers for serviceId=${v.serviceId}');
      }
      final item = items.first;
      _detail('picked: ${item.payItemId} (${item.name},'
          ' ${item.amountType}, local=${item.amountLocalCur} ${item.localCur})');
      _dumpFields(item.toJson(), _detail);
      final amount = _resolveAmount(item, v.amount);
      final quote = await _quoteOnly(client, item, amount, _detail);
      if (willCollect) {
        await _collectAndReport(client, quote, v, _detail);
      } else {
        _quoteOnlyTail(_detail);
      }
    });
  }

  Future<void> _scenarioProduct(SmobilpayClient client) async {
    final product = _cfg.product;
    final willCollect = product != null && product.collect == true;
    final name = 'Collection — product purchase (discover + quote'
        '${willCollect ? " + collect)" : ")"}';
    await _run(name, () async {
      if (product == null) _skip("no 'product' block in config");
      final items =
          await client.masterdata.products(serviceId: product!.serviceId);
      if (items.isEmpty) {
        throw StateError('no products for serviceId=${product.serviceId}');
      }
      final item = items.first;
      _detail('picked: ${item.payItemId} (${item.name},'
          ' ${item.amountType}, local=${item.amountLocalCur} ${item.localCur})');
      _dumpFields(item.toJson(), _detail);
      final amount = _resolveAmount(item, product.amount);
      final quote = await _quoteOnly(client, item, amount, _detail);
      if (willCollect) {
        await _collectAndReport(client, quote, product, _detail);
      } else {
        _quoteOnlyTail(_detail);
      }
    });
  }

  Future<void> _scenarioSubscription(SmobilpayClient client) async {
    final subscription = _cfg.subscription;
    final willCollect = subscription != null && subscription.collect == true;
    final name = 'Collection — subscription top-up (discover + quote'
        '${willCollect ? " + collect)" : ")"}';
    await _run(name, () async {
      if (subscription == null) _skip("no 'subscription' block in config");
      if (subscription!.serviceNumber == null &&
          subscription.customerNumber == null) {
        _skip(
            "subscription block needs either 'serviceNumber' or 'customerNumber'");
      }
      final subs = await client.initiate.subscriptions(
        merchant: subscription.merchant,
        serviceId: subscription.serviceId,
        serviceNumber: subscription.serviceNumber,
        customerNumber: subscription.customerNumber,
      );
      if (subs.isEmpty) {
        throw StateError('no subscriptions for ${subscription.merchant}/'
            '${subscription.serviceId}'
            ' (serviceNumber=${subscription.serviceNumber},'
            ' customerNumber=${subscription.customerNumber})');
      }
      final sub = subs.first;
      _detail('picked: ${sub.payItemId} (${sub.name},'
          ' customer=${sub.customerName},'
          ' amount=${sub.amountLocalCur} ${sub.localCur},'
          ' due=${sub.dueDate})');
      _dumpFields(sub.toJson(), _detail);
      final amount = _resolveAmount(sub, subscription.amount);
      final quote = await _quoteOnly(client, sub, amount, _detail);
      if (willCollect) {
        await _collectAndReport(client, quote, subscription, _detail);
      } else {
        _quoteOnlyTail(_detail);
      }
    });
  }

  Future<void> _scenarioCashin(SmobilpayClient client) async {
    final cashin = _cfg.cashin;
    final willCollect = cashin != null && cashin.collect == true;
    final name = 'Disbursement — cash-in (discover + quote'
        '${willCollect ? " + collect)" : ")"}';
    await _run(name, () async {
      if (cashin == null) _skip("no 'cashin' block in config");
      final items =
          await client.masterdata.cashins(serviceId: cashin!.serviceId);
      if (items.isEmpty) {
        throw StateError('no cashin items for serviceId=${cashin.serviceId}');
      }
      final item = items.first;
      _detail('picked: ${item.payItemId} (${item.name},'
          ' ${item.amountType}, local=${item.amountLocalCur} ${item.localCur})');
      _dumpFields(item.toJson(), _detail);
      final quote = await _quoteOnly(client, item, cashin.amount, _detail);
      if (willCollect) {
        await _collectAndReport(client, quote, cashin, _detail);
      } else {
        _quoteOnlyTail(_detail);
      }
    });
  }

  Future<void> _scenarioVerifyServiceNumber(SmobilpayClient client) async {
    await _run('Account validation — verify serviceNumber', () async {
      final c = _cfg.verify;
      if (c == null) _skip("no 'verify' block in config");
      try {
        final valid = await client.accountValidation.verifyServiceNumber(
          merchant: c!.merchant,
          serviceId: c.serviceId,
          serviceNumber: c.serviceNumber,
        );
        _detail('${c.serviceNumber} for ${c.merchant}/${c.serviceId}'
            ' -> ${valid ? "valid" : "invalid"}');
      } on SmobilpayApiException catch (e) {
        if (e.error?.respCode == 40408) {
          _skip('service ${c!.merchant}/${c.serviceId}'
              ' does not support pre-payment verification (respCode 40408)');
        }
        if (e.error == null && e.rawBody != null && e.rawBody!.isNotEmpty) {
          _detail('rawBody:  ${e.rawBody}');
        }
        rethrow;
      }
    });
  }

  Future<void> _scenarioValidateAccount(SmobilpayClient client) async {
    await _run('Account validation — validate destination', () async {
      final c = _cfg.validate;
      if (c == null) _skip("no 'validate' block in config");
      try {
        final account = await client.accountValidation.validateAccount(
          destination: c!.destination,
          serviceId: c.serviceId,
        );
        _dumpFields(account.toJson(), _detail);
      } on SmobilpayApiException catch (e) {
        if (e.httpStatus == 401) {
          _skip('GET /v2/validate is a restricted endpoint and is not enabled'
              ' for this partner (HTTP 401). Compliance review is required —'
              ' contact your Maviance integration manager.');
        }
        if (e.error == null && e.rawBody != null && e.rawBody!.isNotEmpty) {
          _detail('rawBody:  ${e.rawBody}');
        }
        rethrow;
      }
    });
  }

  Future<void> _scenarioHistoryLast7Days(SmobilpayClient client) async {
    await _run('History - last 7 days', () async {
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 7));
      final rows = await client.verify.historyByDateRange(
        from: weekAgo,
        to: today,
      );
      String fmt(DateTime d) => '${d.year.toString().padLeft(4, "0")}-'
          '${d.month.toString().padLeft(2, "0")}-'
          '${d.day.toString().padLeft(2, "0")}';
      _detail('range:        ${fmt(weekAgo)} -> ${fmt(today)}');
      _detail('transactions: ${rows.length}');
      final sample = rows.length < 30 ? rows.length : 30;
      for (var i = 0; i < sample; i++) {
        final s = rows[i];
        _detail('  - ${s.ptn} : ${s.status},'
            ' ${s.priceLocalCur} ${s.localCur},'
            ' trid=${s.trid}');
      }
      if (rows.isNotEmpty) {
        _detail('first row fields:');
        _dumpFields(rows.first.toJson(), _detail);
      }
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
      } else if (e.rawBody != null && e.rawBody!.isNotEmpty) {
        _detail('rawBody:  ${e.rawBody}');
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

  void _dumpFields(Map<String, dynamic> map, void Function(String) detail) =>
      __dumpFields(map, detail);

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
// Shared scenario helpers
// ---------------------------------------------------------------------------

/// Issues a quote and prints all quote fields.
Future<QuoteResponse> _quoteOnly(
  SmobilpayClient client,
  PaymentItem item,
  int amount,
  void Function(String) detail,
) async {
  final quote = await client.initiate.quote(
    QuoteRequest(amount: amount, payItemId: item.payItemId),
  );
  __dumpFields(quote.toJson(), detail);
  return quote;
}

/// Prints the quote-only tail line (no collect opted in).
void _quoteOnlyTail(void Function(String) detail) {
  detail(
      '(intentionally NOT calling /v2/collectstd — set "collect": true on this block to enable)');
}

/// Chooses the quote amount for items that may or may not carry a catalog
/// price. FIXED-amount items can use the catalog; CUSTOM-amount items need
/// an explicit override on the config block.
int _resolveAmount(PaymentItem item, int? configAmount) {
  if (configAmount != null && configAmount > 0) return configAmount;
  final local = item.amountLocalCur;
  if (local != null && local >= 1.0) return local.toInt();
  throw StateError('item ${item.payItemId} has no fixed catalog amount '
      '(got $local). Set "amount" in this block of smoke-test.json.');
}

/// Real collect, gated by `c.collect == true`.
///
/// Called from every collection/disbursement scenario when the flow block
/// opts in with `"collect": true`. Validates required fields, builds a
/// CollectionRequest with all populated pass-through fields, calls
/// /v2/collectstd, prints the response, sleeps 1s, and polls
/// /v2/verifytx once to surface the latest server-side status.
Future<void> _collectAndReport(
  SmobilpayClient client,
  QuoteResponse quote,
  _CollectFields c,
  void Function(String) detail,
) async {
  if (c.customerPhonenumber == null || c.customerPhonenumber!.isEmpty) {
    throw const _SkipException(
        "'collect' is true but 'customerPhonenumber' is missing");
  }
  if (c.customerEmailaddress == null || c.customerEmailaddress!.isEmpty) {
    throw const _SkipException(
        "'collect' is true but 'customerEmailaddress' is missing");
  }
  // Note: serviceNumber is optional in the helper — the server enforces
  // it per service via isReqServiceNumber. If serviceNumber is missing
  // when required, the API returns 4xx and the FAIL handler surfaces it.

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
  detail('POST /v2/collectstd  trid=$trid'
      '  customerPhonenumber=${c.customerPhonenumber}'
      '${c.serviceNumber != null ? "  serviceNumber=${c.serviceNumber}" : ""}');
  final resp = await client.confirm.collect(request);
  __dumpFields(resp.toJson(), detail);

  // One-shot verifyTransaction poll to surface the latest server-side status.
  await Future<void>.delayed(const Duration(seconds: 1));
  try {
    final statuses = await client.verify.verifyTransaction(ptn: resp.ptn);
    if (statuses.isNotEmpty) {
      detail('verifyTransaction.status: ${statuses.first.status}');
    } else {
      detail('verifyTransaction returned no rows yet');
    }
  } on SmobilpayApiException catch (e) {
    detail('verifyTransaction failed (HTTP ${e.httpStatus}); ignoring');
  }
}

// ---------------------------------------------------------------------------
// Internal exceptions
// ---------------------------------------------------------------------------

class _SkipException implements Exception {
  const _SkipException(this.message);
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

/// Prints every field of [map] as `key: value` detail lines, in sorted key
/// order. Used by every scenario to dump the complete response.
void __dumpFields(Map<String, dynamic> map, void Function(String) detail) {
  final keys = map.keys.toList()..sort();
  for (final k in keys) {
    final v = map[k];
    final pretty = switch (v) {
      null => '<null>',
      List() => '[${v.length} items]',
      Map() => v.toString(),
      _ => v.toString(),
    };
    detail('$k: $pretty');
  }
}

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

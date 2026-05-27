import '../exception.dart';
import '../http/lenient_date.dart';
import '../http/lenient_num.dart';
import '../http/query_params.dart';
import '../http/transport.dart';
import '../model/commission.dart';
import '../model/enums.dart';

/// Status and account verification endpoints. Backed by the `Verify`
/// spec tag.
class VerifyApi {
  /// Creates a [VerifyApi].
  VerifyApi(this._transport);

  final HttpTransport _transport;

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
      QueryParams()
        ..add('ptn', ptn)
        ..add('trid', trid),
    ) as List<dynamic>;
    return json
        .map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /v2/historystd?ptn=...`
  Future<List<PaymentStatus>> historyByPtn(String ptn) async {
    final json = await _transport.getJson(
      '/v2/historystd',
      QueryParams()..add('ptn', ptn),
    ) as List<dynamic>;
    return json
        .map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /v2/historystd?trid=...`
  Future<List<PaymentStatus>> historyByTrid(String trid) async {
    final json = await _transport.getJson(
      '/v2/historystd',
      QueryParams()..add('trid', trid),
    ) as List<dynamic>;
    return json
        .map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /v2/historystd?timestamp_from=...&timestamp_to=...`
  ///
  /// Both dates are treated as date-only (time is ignored). The range
  /// `[from, to]` is inclusive. Throws [SmobilpayConfigException] when
  /// [to] is before [from].
  Future<List<PaymentStatus>> historyByDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromDate = DateTime.utc(from.year, from.month, from.day);
    final toDate = DateTime.utc(to.year, to.month, to.day);
    if (toDate.isBefore(fromDate)) {
      throw const SmobilpayConfigException('to date is before from date');
    }
    final fromInstant = DateTime.utc(from.year, from.month, from.day);
    final toInstant = DateTime.utc(to.year, to.month, to.day, 23, 59, 59);
    final json = await _transport.getJson(
      '/v2/historystd',
      QueryParams()
        ..add('timestamp_from', _formatHistoryInstant(fromInstant))
        ..add('timestamp_to', _formatHistoryInstant(toInstant)),
    ) as List<dynamic>;
    return json
        .map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Formats a [DateTime] as `yyyy-MM-ddTHH:mm:ssZ` (no fractional seconds).
  ///
  /// Matches Java's `DateTimeFormatter.ISO_OFFSET_DATE_TIME` output for
  /// UTC datetimes.
  static String _formatHistoryInstant(DateTime dt) {
    final u = dt.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final mo = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    final h = u.hour.toString().padLeft(2, '0');
    final mi = u.minute.toString().padLeft(2, '0');
    final s = u.second.toString().padLeft(2, '0');
    return '$y-$mo-${d}T$h:$mi:${s}Z';
  }
}

/// Authenticated probe response from `GET /v2/ping`.
class Ping {
  /// Creates a [Ping].
  const Ping({
    required this.time,
    required this.version,
    required this.nonce,
    required this.key,
  });

  /// Decodes from JSON.
  factory Ping.fromJson(Map<String, dynamic> json) => Ping(
        time: LenientDate.parse(json['time'] as String),
        version: json['version'] as String,
        nonce: json['nonce'] as String,
        key: json['key'] as String,
      );

  /// Current server time (UTC).
  final DateTime time;

  /// Server-emitted protocol version.
  final String version;

  /// Nonce echoed from the request.
  final String nonce;

  /// Public token of the user that sent the request.
  final String key;

  /// Encodes this [Ping] as a JSON map.
  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'version': version,
        'nonce': nonce,
        'key': key,
      };

  @override
  String toString() =>
      'Ping(time: $time, version: $version, nonce: $nonce, key: $key)';
}

/// Authenticated agent profile from `GET /v2/account`.
class Account {
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
        balance: LenientNum.asDouble(json['balance']),
        currency: json['currency'] as String,
        key: json['key'] as String,
        agentId: json['agentId'] as String,
        agentName: json['agentName'] as String,
        agentAddress: json['agentAddress'] as String?,
        agentPhonenumber: json['agentPhonenumber'] as String?,
        companyName: json['companyName'] as String?,
        companyAddress: json['companyAddress'] as String?,
        companyPhonenumber: json['companyPhonenumber'] as String?,
        limitMax: LenientNum.asDouble(json['limitMax']),
        limitRemaining: LenientNum.asDouble(json['limitRemaining']),
      );

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

  /// Encodes this [Account] as a JSON map.
  Map<String, dynamic> toJson() => {
        'agentAddress': agentAddress,
        'agentId': agentId,
        'agentName': agentName,
        'agentPhonenumber': agentPhonenumber,
        'balance': balance,
        'companyAddress': companyAddress,
        'companyName': companyName,
        'companyPhonenumber': companyPhonenumber,
        'currency': currency,
        'key': key,
        'limitMax': limitMax,
        'limitRemaining': limitRemaining,
      };
}

/// Current state of a previously-issued payment collection.
class PaymentStatus {
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
  ///
  /// Accepts the wire key `serviceid` (lowercase i, per partner spec) and
  /// also the camelCase alias `serviceId` for forward-compatibility.
  factory PaymentStatus.fromJson(Map<String, dynamic> json) => PaymentStatus(
        ptn: json['ptn'] as String,
        serviceId: (json['serviceid'] ?? json['serviceId']).toString(),
        merchant: json['merchant'] as String?,
        timestamp: LenientDate.parseOrNull(json['timestamp'] as String?),
        receiptNumber: json['receiptNumber'] as String?,
        veriCode: json['veriCode'] as String?,
        clearingDate: LenientDate.parseOrNull(json['clearingDate'] as String?),
        trid: json['trid'] as String?,
        priceLocalCur: LenientNum.asDoubleOrNull(json['priceLocalCur']),
        priceSystemCur: LenientNum.asDoubleOrNull(json['priceSystemCur']),
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
        errorCode: LenientNum.asIntOrNull(json['errorCode']) ?? 0,
        tag: json['tag'] as String?,
        commission: json['commission'] is Map<String, dynamic>
            ? Commission.fromJson(json['commission'] as Map<String, dynamic>)
            : null,
      );

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

  /// Encodes this [PaymentStatus] as a JSON map.
  Map<String, dynamic> toJson() => {
        'clearingDate': clearingDate?.toIso8601String(),
        'commission': commission?.toJson(),
        'errorCode': errorCode,
        'localCur': localCur,
        'merchant': merchant,
        'payItemDescr': payItemDescr,
        'payItemId': payItemId,
        'pin': pin,
        'priceLocalCur': priceLocalCur,
        'priceSystemCur': priceSystemCur,
        'ptn': ptn,
        'receiptNumber': receiptNumber,
        'serviceId': serviceId,
        'status': status.wireName,
        'systemCur': systemCur,
        'tag': tag,
        'timestamp': timestamp?.toIso8601String(),
        'trid': trid,
        'veriCode': veriCode,
      };
}

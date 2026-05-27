// ignore_for_file: avoid_print

// Quote-then-confirm flow with HTTP 498 (quote expired) handling.
//
// This example deliberately STOPS after the quote unless you set
// `runCollect: true` below. Collecting moves real money.
//
// Usage:
//   export SMOBILPAY_BASE_URL=https://api.example.invalid
//   export SMOBILPAY_PUBLIC_KEY=...
//   export SMOBILPAY_SECRET_KEY=...
//   dart run example/quote_collection.dart

import 'dart:io';
import 'package:smobilpay/smobilpay.dart';

const bool runCollect = false; // set to true to execute /v2/collectstd

Future<void> main() async {
  final client = SmobilpayClient(
    config: SmobilpayConfig(
      baseUrl: Uri.parse(Platform.environment['SMOBILPAY_BASE_URL']!),
      publicKey: Platform.environment['SMOBILPAY_PUBLIC_KEY']!,
      secretKey: Platform.environment['SMOBILPAY_SECRET_KEY']!,
    ),
  );
  try {
    final items = await client.masterdata.cashouts(serviceId: 20053);
    if (items.isEmpty) {
      print('No cashout items for serviceId=20053');
      return;
    }
    final item = items.first;
    print('Picked: ${item.payItemId} (${item.name})');

    final quote = await _quoteWithRetry(client, item, amount: 500);
    print('Quote: ${quote.quoteId}, expires ${quote.expiresAt}');
    print('Price: ${quote.priceLocalCur} ${quote.localCur}');

    if (!runCollect) {
      print('(Set runCollect: true to call /v2/collectstd. Skipping.)');
      return;
    }

    final response = await client.confirm.collect(
      CollectionRequest(
        quoteId: quote.quoteId,
        customerPhonenumber: '699999999',
        customerEmailaddress: 'demo@example.invalid',
      ),
    );
    print('Collected: ${response.ptn} (${response.status})');
  } on SmobilpayApiException catch (e) {
    print('API error (HTTP ${e.httpStatus}): respCode=${e.error?.respCode}, '
        'devMsg=${e.error?.devMsg}');
  } on SmobilpayAuthException catch (e) {
    print(
        'Auth error (HTTP ${e.httpStatus}, oauth=${e.oauthError}): ${e.message}');
  } finally {
    client.close();
  }
}

/// Quotes, retrying once on HTTP 498 (quote expired).
Future<QuoteResponse> _quoteWithRetry(SmobilpayClient client, PaymentItem item,
    {required int amount}) async {
  try {
    return await client.initiate.quote(
      QuoteRequest(amount: amount, payItemId: item.payItemId),
    );
  } on SmobilpayApiException catch (e) {
    if (e.httpStatus == 498) {
      print('Quote expired, retrying...');
      return await client.initiate.quote(
        QuoteRequest(amount: amount, payItemId: item.payItemId),
      );
    }
    rethrow;
  }
}

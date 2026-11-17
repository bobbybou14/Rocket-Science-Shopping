import 'dart:io';

import 'package:rocket_science_shopping/service/ocr_repair_service.dart';
import 'package:rocket_science_shopping/service/receipt_parser_service.dart';
import 'package:rocket_science_shopping/service/receipt_reconciliation_service.dart';

ParsedReceipt parse(String text) =>
    ReceiptParserService.parse(OcrRepairService.repair(text));

void check(String label, bool passed) {
  if (!passed) throw StateError('FAIL: $label');
  stdout.writeln('PASS: $label');
}

String? issueFor(ParsedReceipt receipt, {double? overrideDeposits}) {
  final purchases = receipt.items.where((item) => !item.isPostSubtotalDeposit);
  final deposits = receipt.items.where((item) => item.isPostSubtotalDeposit);
  return ReceiptReconciliationService.issue(
    receiptSubtotal: receipt.subtotal,
    receiptTotal: receipt.total,
    tax: receipt.tax,
    itemSubtotal: purchases.fold<double>(0, (sum, item) => sum + item.price),
    postSubtotalDeposits:
        overrideDeposits ??
        deposits.fold<double>(0, (sum, item) => sum + item.price),
    unresolvedPrices: receipt.items
        .where((item) => item.priceNeedsReview)
        .length,
  );
}

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final fixture = File(
    '${root.path}/test/fixtures/hayters_post_subtotal_deposits.txt',
  ).readAsStringSync();
  final receipt = parse(fixture);

  check(
    'Hayters store recognized',
    receipt.storeName == 'Hayters Turkey Products Inc.',
  );
  final purchases = receipt.items.where((item) => !item.isPostSubtotalDeposit);
  final deposits = receipt.items
      .where((item) => item.isPostSubtotalDeposit)
      .toList();
  check(
    'Four purchases retain their prices and quantities',
    purchases.map((item) => item.price.toStringAsFixed(2)).join(',') ==
            '48.95,3.14,27.83,5.25' &&
        purchases.every((item) => item.quantity == 1),
  );
  check(
    'All three deposits are counted once, including detached amounts',
    deposits.map((item) => item.price.toStringAsFixed(2)).join(',') ==
            '1.50,0.10,3.00' &&
        deposits.every((item) => item.name == 'Deposit' && item.quantity == 1),
  );
  check(
    'Detached deposit label and amount retained for review',
    deposits.last.sourceLine == '3.00 Deposit\n\$3.00',
  );
  check(
    'Printed subtotal, HST, and total reconcile when deposits are counted',
    receipt.subtotal == 85.17 &&
        receipt.tax == 10.39 &&
        receipt.total == 100.16 &&
        receipt.reviewWarnings.isEmpty &&
        issueFor(receipt) == null,
  );
  check(
    'An edited deposit that causes a mismatch blocks confirmation',
    issueFor(receipt, overrideDeposits: 4.59) != null,
  );
  final conflicting = parse(
    fixture.replaceFirst('Deposit \$1.50', 'Deposit \$1.80'),
  );
  check(
    'Conflicting inline amounts require review',
    conflicting.items
            .where((item) => item.isPostSubtotalDeposit)
            .first
            .priceNeedsReview &&
        issueFor(conflicting) != null,
  );
  final detachedConflict = parse(
    fixture.replaceFirst('\n\$3.00\n', '\n\$3.08\n'),
  );
  check(
    'Conflicting detached amounts require review',
    detachedConflict.items.last.priceNeedsReview &&
        issueFor(detachedConflict) != null,
  );
  final recovered = parse(fixture.replaceFirst('HST \$10.39', 'HST \$10.'));
  check(
    'Recovered HST excludes deposits',
    recovered.tax == 10.39 && issueFor(recovered) == null,
  );
  final before = parse(
    'Item 2.99\n+Deposit \$0.10\nSubtotal \$3.09\nHST \$0.39\nTotal \$3.48',
  );
  check(
    'Deposits before subtotal still count as part of the subtotal',
    before.items.length == 2 &&
        before.items.every((item) => !item.isPostSubtotalDeposit) &&
        issueFor(before) == null,
  );
  final footer = parse('$fixture\n4.50 Deposit \$4.50');
  check(
    'Deposit text after the total is ignored',
    footer.items.length == 7 && issueFor(footer) == null,
  );
}

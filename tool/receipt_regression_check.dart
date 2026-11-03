import 'dart:io';

import 'package:rocket_science_shopping/service/ocr_repair_service.dart';
import 'package:rocket_science_shopping/service/receipt_parser_service.dart';
import 'package:rocket_science_shopping/service/receipt_reconciliation_service.dart';

int checks = 0;
void check(String name, bool condition) {
  if (!condition) throw StateError('FAIL: $name');
  checks++;
  stdout.writeln('PASS: $name');
}

bool money(double actual, double expected) =>
    (actual * 100).round() == (expected * 100).round();

double sum(ParsedReceipt receipt) =>
    receipt.items.fold<double>(0, (sum, item) => sum + item.price);

ParsedReceipt parse(String text) =>
    ReceiptParserService.parse(OcrRepairService.repair(text));

String? issue(ParsedReceipt receipt) => ReceiptReconciliationService.issue(
  receiptSubtotal: receipt.subtotal,
  receiptTotal: receipt.total,
  tax: receipt.tax,
  itemSubtotal: sum(receipt),
  unresolvedPrices: receipt.items.where((item) => item.priceNeedsReview).length,
);

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final food = File(
    '${root.path}/test/fixtures/food_basics_incomplete_price.txt',
  ).readAsStringSync();
  final noFrills = File(
    '${root.path}/test/fixtures/no_frills_seven_items.txt',
  ).readAsStringSync();

  final broken = parse(food);
  final cherry = broken.items.singleWhere(
    (item) => item.name.contains('ZERO CHERRY'),
  );
  check(
    'Food Basics retains 11 lines including incomplete price and deposit',
    broken.items.length == 11,
  );
  check(
    'Incomplete price is flagged, not invented as 0.98 or 7.98',
    cherry.priceNeedsReview && cherry.price == 0 && cherry.confidenceScore == 0,
  );
  check(
    'Original incomplete OCR text is retained',
    cherry.sourceLine.endsWith('H .98'),
  );
  check('Known item amounts remain 53.49', money(sum(broken), 53.49));
  check(
    'Damaged subtotal recovers to 61.47 from independent receipt figures',
    money(broken.subtotal, 61.47) && broken.subtotalWasRecovered,
  );
  check(
    'Tax and total stay 4.54 and 66.01',
    money(broken.tax, 4.54) && money(broken.total, 66.01),
  );
  check('Unresolved price blocks confirmation', issue(broken) != null);
  check(
    'Savings summaries do not become products or negative discounts',
    !broken.items.any(
      (item) =>
          item.name.toUpperCase().contains('SAVING') ||
          item.name.toUpperCase().contains('DISCOUNT') ||
          item.price < 0,
    ),
  );

  final corrected = parse(food.replaceFirst('H .98', 'H 7.98'));
  check(
    'Readable Food Basics prices total 61.47',
    money(sum(corrected), 61.47),
  );
  check(
    'Readable Food Basics receipt passes reconciliation',
    issue(corrected) == null,
  );
  check(
    'Soup quantities are 3, 3, 3',
    corrected.items
        .where((item) => item.name.contains('SOUP'))
        .every((item) => item.quantity == 3),
  );
  check(
    'Pizza quantity is 2',
    corrected.items
            .singleWhere((item) => item.name.contains('PIZZA'))
            .quantity ==
        2,
  );
  check(
    'Deposit remains 0.60 and product quantities sum to 18',
    money(corrected.items.last.price, 0.60) &&
        corrected.items
                .take(10)
                .fold<double>(0, (sum, item) => sum + item.quantity) ==
            18,
  );

  final misread = parse(food.replaceFirst('H .98', 'H 1.98'));
  check(
    'A plausible but wrong 1.98 price is not silently changed',
    money(
      misread.items
          .singleWhere((item) => item.name.contains('ZERO CHERRY'))
          .price,
      1.98,
    ),
  );
  check(
    'Six-dollar discrepancy blocks confirmation',
    money(sum(misread), 55.47) && issue(misread)!.contains(r'$6.00'),
  );

  final explicitCents = parse(food.replaceFirst('H .98', 'H 0.98'));
  check(
    'Explicit 0.98 remains a readable price, with discrepancy still blocked',
    !explicitCents.items
            .singleWhere((item) => item.name.contains('ZERO CHERRY'))
            .priceNeedsReview &&
        issue(explicitCents) != null,
  );

  final damagedTotal = parse(food.replaceFirst('TOTAL 66.01', 'TOTAL 66.O1'));
  check(
    'Letter O in summary total recovers with corroboration',
    money(damagedTotal.total, 66.01) && damagedTotal.totalWasRecovered,
  );
  final hyphens = parse(
    food
        .replaceFirst('61 47', '61-47')
        .replaceFirst('TOTAL 66.01', 'TOTAL 66-01'),
  );
  check(
    'Two damaged summaries recover with exact matching payment',
    money(hyphens.subtotal, 61.47) && money(hyphens.total, 66.01),
  );
  final unsupported = parse(
    food
        .replaceFirst('TOTAL 66.01', 'TOTAL 66.O1')
        .replaceFirst('CREDIT CR 66.01', 'CREDIT CR 60.01'),
  );
  check(
    'Conflicting payment does not corroborate two damaged summaries',
    unsupported.subtotal == 0 && unsupported.total == 0,
  );
  final missingTotal = parse(
    food
        .replaceFirst('SUBTOTAL 61 47', 'SUBTOTAL 61.47')
        .replaceFirst('TOTAL 66.01', 'TOTAL unread'),
  );
  check(
    'Unread total recovers only from matching explicit payment',
    money(missingTotal.total, 66.01) && missingTotal.totalWasRecovered,
  );
  final conflictingTax = parse(
    food
        .replaceFirst('% 4.54', '% 5.54')
        .replaceFirst('SUBTOTAL 61 47', 'SUBTOTAL 61.47'),
  );
  check(
    'Explicit contradictory tax is preserved, not forced to balance',
    money(conflictingTax.tax, 5.54) && issue(conflictingTax) != null,
  );

  final no = parse(noFrills);
  check('No Frills still has seven rows', no.items.length == 7);
  check(
    'No Frills prices and totals unchanged',
    money(sum(no), 32.48) &&
        money(no.subtotal, 32.48) &&
        money(no.tax, 1.20) &&
        money(no.total, 33.68),
  );
  check(
    'No Frills requires no price repair',
    !no.items.any((item) => item.priceNeedsReview) && issue(no) == null,
  );

  String? validate(double itemSum, {int missing = 0}) =>
      ReceiptReconciliationService.issue(
        receiptSubtotal: 61.47,
        receiptTotal: 66.01,
        tax: 4.54,
        itemSubtotal: itemSum,
        unresolvedPrices: missing,
      );
  check('One-cent shortfall remains visible', validate(61.46) != null);
  check('One-cent overage remains visible', validate(61.48) != null);
  check(
    'Missing-price state cannot pass just because numbers happen to balance',
    validate(61.47, missing: 1) != null,
  );
  check('Non-finite amounts cannot pass', validate(double.nan) != null);
  check(
    'Floating point noise smaller than a cent does not block',
    validate(61.47000000001) == null,
  );
  stdout.writeln('\n$checks regression checks passed.');
}

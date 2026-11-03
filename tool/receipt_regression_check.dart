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
  final independentText = File(
    '${root.path}/test/fixtures/independent_offers_damaged_price.txt',
  ).readAsStringSync();
  final independent = parse(independentText);
  check(
    'Independent offer receipt retains all 16 product rows',
    independent.items.length == 16,
  );
  check(
    'Damaged Independent header is recognized',
    independent.storeName == 'Independent Grocers',
  );
  check(
    'Standalone final total is read and subtotal recovered independently',
    money(independent.total, 100.46) &&
        money(independent.tax, 5.84) &&
        money(independent.subtotal, 94.62) &&
        independent.subtotalWasRecovered,
  );
  final expectedPrices = [
    7.99,
    5.00,
    6.99,
    5.00,
    3.00,
    1.99,
    4.49,
    8.99,
    7.98,
    1.75,
    6.44,
    5.00,
    0.00,
    3.50,
    10.00,
    5.00,
  ];
  check(
    'Offer prices do not replace actual purchase amounts',
    independent.items.length == expectedPrices.length &&
        List.generate(
          expectedPrices.length,
          (index) =>
              money(independent.items[index].price, expectedPrices[index]),
        ).every((value) => value),
  );
  final expectedQuantities = [1, 1, 1, 4, 2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2];
  check(
    'Every Independent quantity survives damaged markers and decimal unit prices',
    independent.items.length == expectedQuantities.length &&
        List.generate(
          expectedQuantities.length,
          (index) =>
              independent.items[index].quantity == expectedQuantities[index],
        ).every((value) => value),
  );
  check(
    'Gatorade, Oreo, and Coke retain their product names',
    independent.items[0].name.contains('GATORADE') &&
        independent.items[6].name.contains('OREO') &&
        independent.items[7].name.contains('COCA-COLA'),
  );
  check(
    'Spaced price remains one unresolved row with original OCR',
    independent.items.where((item) => item.priceNeedsReview).length == 1 &&
        independent.items[12].sourceLine.endsWith('5 50'),
  );
  check(
    'Known amounts total 83.12 and missing price blocks confirmation',
    money(sum(independent), 83.12) && issue(independent) != null,
  );
  final verifiedIndependent = parse(
    independentText.replaceFirst('MRJ 5 50', 'MRJ 5.50'),
  );
  check(
    'Readable 5.50 still leaves the six-dollar OCR price discrepancy',
    verifiedIndependent.items.length == 16 &&
        money(sum(verifiedIndependent), 88.62) &&
        issue(verifiedIndependent) != null,
  );
  final correctedIndependent = parse(
    independentText
        .replaceFirst('MRJ 5 50', 'MRJ 5.50')
        .replaceFirst('VEC MEAL RP MJ 1.99', 'VEC MEAL RP MJ 7.99'),
  );
  check(
    'Two explicitly corrected prices reconcile to the printed subtotal',
    correctedIndependent.items.length == 16 &&
        money(sum(correctedIndependent), 94.62) &&
        issue(correctedIndependent) == null,
  );
  final bread = parse('''YOUR INDEPENDENT GROCER
(2) 06038302289 NN WHITE BREAD HRJ
20 \$2.50 5.00
SUBTOTAL 5.00
TOTAL 5.00''');
  check(
    'Earlier bread case with barcode prefix and damaged @ stays quantity two',
    bread.items.length == 1 &&
        bread.items.single.quantity == 2 &&
        money(bread.items.single.price, 5),
  );
  for (final continuation in [
    r'1 @ $7.99 ea 7.99',
    r'10 $7.99 ea 7.99',
    r'1 @ $4.49 ea oc 4.49',
  ]) {
    final receipt = parse(
      '12345678901 TEST PRODUCT\n$continuation\nTOTAL 7.99',
    );
    check(
      'Decimal unit price never supplies quantity: $continuation',
      receipt.items.length == 1 && receipt.items.single.quantity == 1,
    );
  }
  final explicitEach = parse('TEST PRODUCT 2 EA 5.00\nTOTAL 5.00');
  check(
    'Explicit integer EA quantity remains supported',
    explicitEach.items.single.quantity == 2,
  );
  final separatedTotal = parse('TOTAL\n100.46\n123456789012');
  check(
    'Standalone total accepts only the immediate amount line',
    money(separatedTotal.total, 100.46),
  );
  final interruptedTotal = parse('TOTAL\nCard Number:\n100.46');
  check(
    'Interrupted total heading cannot consume a later footer number',
    interruptedTotal.total == 0,
  );
  final offerOnly = parse(r'''12345678901 TEST PRODUCT
$4.49 ea or 2/$8.00
TOTAL 8.00''');
  check(
    'An offer alone never creates a purchased item',
    offerOnly.items.isEmpty,
  );
  stdout.writeln('\n$checks regression checks passed.');
}

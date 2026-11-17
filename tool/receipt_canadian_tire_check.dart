import 'dart:io';

import 'package:rocket_science_shopping/service/ocr_repair_service.dart';
import 'package:rocket_science_shopping/service/receipt_parser_service.dart';
import 'package:rocket_science_shopping/service/receipt_reconciliation_service.dart';

int checks = 0;
void check(String label, bool result) {
  if (!result) throw StateError('FAIL: $label');
  checks++;
  stdout.writeln('PASS: $label');
}

bool money(double a, double b) => (a * 100).round() == (b * 100).round();
ParsedReceipt parse(String text) =>
    ReceiptParserService.parse(OcrRepairService.repair(text));
void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final text = File(
    '${root.path}/test/fixtures/canadian_tire_saved_annotation.txt',
  ).readAsStringSync();
  final receipt = parse(text);
  check('Canadian Tire has three purchased items', receipt.items.length == 3);
  check(
    'SAVED annotation is neither a purchase nor another deduction',
    !receipt.items.any(
      (item) => item.name.contains('SAVED') || item.isDiscount,
    ),
  );
  check(
    'All three observed prices are unchanged',
    receipt.items.length == 3 &&
        money(receipt.items[0].price, 109.93) &&
        money(receipt.items[1].price, 11.99) &&
        money(receipt.items[2].price, 22.99),
  );
  check(
    'Every item remains quantity one',
    receipt.items.every((item) => item.quantity == 1),
  );
  check(
    'Hyphenated retailer item code is retained before X',
    receipt.items.first.name.startsWith('168-0114-2 '),
  );
  check(
    'Canadian Tire store header is recognized',
    receipt.storeName == 'Canadian Tire',
  );
  final sum = receipt.items.fold<double>(
    0,
    (total, item) => total + item.price,
  );
  check('Item amounts add to 144.91', money(sum, 144.91));
  check(
    'Subtotal, recovered tax and total reconcile',
    money(receipt.subtotal, 144.91) &&
        money(receipt.tax, 18.84) &&
        money(receipt.total, 163.75) &&
        ReceiptReconciliationService.issue(
              receiptSubtotal: receipt.subtotal,
              receiptTotal: receipt.total,
              tax: receipt.tax,
              itemSubtotal: sum,
              unresolvedPrices: 0,
            ) ==
            null,
  );
  check(
    'Uncertain printed tax still carries recovery warning',
    receipt.reviewWarnings.any(
      (warning) => warning.startsWith('Tax calculated'),
    ),
  );
  for (final annotation in [
    r'SAVED $160.06',
    r'( SAVED $160.06 )',
    r'Saving 1.74',
    r'SAVINGS $1.74',
  ]) {
    final r = parse(text.replaceFirst(r'(SAVED $160.06)', annotation));
    check(
      'Single-amount savings annotation is informational: $annotation',
      r.items.length == 3 && money(r.items.first.price, 109.93),
    );
  }
  final namedProduct = parse('SAVED SOAP 2.99\nSUBTOTAL 2.99\nTOTAL 2.99');
  check(
    'A product name containing SAVED is not discarded',
    namedProduct.items.length == 1 &&
        money(namedProduct.items.single.price, 2.99),
  );
  final quantity = parse(r'''TEST PRODUCT
2 @ $3.00 6.00
SUBTOTAL 6.00
TOTAL 6.00''');
  check(
    'Genuine quantity-price continuation still works',
    quantity.items.length == 1 &&
        quantity.items.single.quantity == 2 &&
        money(quantity.items.single.price, 6),
  );
  final discount = parse(
    'TEST CHICKEN 9.75\n(9.75@40.00%) -3.90\nSUBTOTAL 5.85\nTOTAL 5.85',
  );
  check(
    'Real percentage discounts are still applied once',
    discount.items.length == 1 && money(discount.items.single.price, 5.85),
  );
  stdout.writeln('\n$checks Canadian Tire checks passed.');
}

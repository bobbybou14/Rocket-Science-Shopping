import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:rocket_science_shopping/service/ocr_repair_service.dart';
import 'package:rocket_science_shopping/service/receipt_parser_service.dart';
import 'package:rocket_science_shopping/service/receipt_reconciliation_service.dart';
import 'package:rocket_science_shopping/service/receipt_row_reconstruction_service.dart';

int checks = 0;
void check(String name, bool condition) {
  if (!condition) throw StateError('FAIL: $name');
  checks++;
  stdout.writeln('PASS: $name');
}

bool money(double a, double b) => (a * 100).round() == (b * 100).round();
String reconstruct(List<ReceiptOcrFragment> fragments) =>
    ReceiptRowReconstructionService.reconstruct(
      fragments,
      fallbackText: 'fallback',
    );
List<ReceiptOcrFragment> load(String name) {
  final root = File.fromUri(Platform.script).parent.parent;
  final rows =
      jsonDecode(File('${root.path}/test/fixtures/$name').readAsStringSync())
          as List;
  return rows
      .map(
        (row) => ReceiptOcrFragment(
          text: row['text'] as String,
          corners: (row['corners'] as List)
              .map(
                (point) => math.Point<double>(
                  (point[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                ),
              )
              .toList(),
        ),
      )
      .toList();
}

ParsedReceipt parse(String text) =>
    ReceiptParserService.parse(OcrRepairService.repair(text));
void main() {
  final fragments = load('food_basics_weighted_geometry.json');
  final text = reconstruct(fragments);
  final receipt = parse(text);
  check(
    'Actual geometry retains all 17 purchased products',
    receipt.items.length == 17,
  );
  final expectedNames = [
    'SELECTION CR ONI',
    'SELECTION PITTED',
    'SELECT.CHIC.TAS.',
    'TRRS.BL.CHEE.DRE',
    'SELECTION WATERM',
    'FF CHICKEN THIGH',
    'WRAPPED BROCCOLI',
    'LEMON',
    'TOMATO ITALIAN',
    'CUCUMBER SEEDLES',
    'HOT PEPPER JALAP',
    'CMATE MACCHIATO',
    'SELECT.CHEESE BL',
    'PHILADEL.LIGH.CR',
    'MODH.2 DAHI YOG',
    'CA TRAD.BLUE CHEESE',
    'HAMBURGER BUNS',
  ];
  final expectedPrices = [
    1.49,
    1.99,
    13.79,
    3.49,
    5.79,
    5.85,
    1.25,
    0.99,
    0.49,
    0.99,
    3.71,
    4.99,
    5.99,
    0.99,
    1.24,
    6.49,
    2.29,
  ];
  check(
    'Every product name and net price matches the receipt photo',
    receipt.items.length == expectedNames.length &&
        List.generate(
          expectedNames.length,
          (index) =>
              receipt.items[index].name.startsWith(expectedNames[index]) &&
              money(receipt.items[index].price, expectedPrices[index]),
        ).every((value) => value),
  );
  check(
    'Department headings never become purchased items',
    !receipt.items.any(
      (item) => [
        'GROCERY',
        'MEAT',
        'PRODUCE',
        'DAIRY',
        'DELI CHEESE',
        'COMM. BAKERY',
      ].contains(item.name),
    ),
  );
  check(
    'Tomato weight and amount survive alignment and parsing',
    receipt.items[8].quantity == 0.155 &&
        receipt.items[8].isWeightedItem &&
        money(receipt.items[8].price, 0.49),
  );
  check(
    'Pepper weight survives damaged @ marker',
    receipt.items[10].quantity == 0.345 &&
        receipt.items[10].isWeightedItem &&
        money(receipt.items[10].price, 3.71),
  );
  check(
    'Both discount annotations are retained in product source text',
    receipt.items[5].sourceLine.contains('-3.90') &&
        receipt.items[14].sourceLine.contains('-1.25'),
  );
  check(
    'Discount annotations do not become extra products',
    !receipt.items.any((item) => item.isDiscount || item.name.contains('%')),
  );
  final sum = receipt.items.fold<double>(
    0,
    (total, item) => total + item.price,
  );
  check('Net item amounts add to 61.82', money(sum, 61.82));
  check(
    'Tax and unrounded receipt total remain 2.74 and 64.56',
    money(receipt.subtotal, 61.82) &&
        money(receipt.tax, 2.74) &&
        money(receipt.total, 64.56),
  );
  check(
    'Receipt reconciles without discarding broccoli or changing weights',
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
    'Cash rounding and savings summaries are not product discounts',
    !receipt.items.any(
      (item) =>
          item.name.contains('ROUNDED') || item.name.contains('discounts'),
    ),
  );
  check(
    'Fragment recognition order cannot change reconstructed rows',
    reconstruct(fragments.reversed.toList()) == text,
  );
  for (final degrees in [90, 180, 270, 23]) {
    final angle = degrees * math.pi / 180;
    final rotated = fragments
        .map(
          (fragment) => ReceiptOcrFragment(
            text: fragment.text,
            corners: fragment.corners
                .map(
                  (point) => math.Point<double>(
                    point.x * math.cos(angle) - point.y * math.sin(angle),
                    point.x * math.sin(angle) + point.y * math.cos(angle),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    check(
      'Actual geometry remains correct after $degrees degree rotation',
      reconstruct(rotated) == text,
    );
  }
  final no = reconstruct(load('no_frills_geometry.json')).split('\n');
  final codes = [
    '05727116272',
    '06038305895',
    '06563323292',
    '06810089634',
    '05621004134',
    '06038300740',
    '06940100767',
  ];
  final prices = ['6. 25', '1. 50', '3.00', '4.99', '2. 25', '2. 49', '12.00'];
  check(
    'Earlier actual No Frills geometry still pairs all seven prices',
    List.generate(
      codes.length,
      (index) => no.any(
        (line) => line.startsWith(codes[index]) && line.endsWith(prices[index]),
      ),
    ).every((value) => value),
  );
  check(
    'No Frills subtotal stays on its own row',
    no.contains('SUBTOTAL 32. 48'),
  );
  for (final separator in ['@', '9', '8', '']) {
    final r = parse(
      'TEST CHICKEN 9.75\n(9.75${separator}40.00%) -3.90\nSUBTOTAL 5.85\nTOTAL 5.85',
    );
    check(
      'Explicit 40 percent deduction supports separator "$separator"',
      r.items.length == 1 && money(r.items.single.price, 5.85),
    );
  }
  final badBase = parse('TEST CHICKEN 10.00\n(9.75@40.00%) -3.90');
  check(
    'A conflicting discount base cannot silently change its predecessor',
    money(badBase.items.first.price, 10) &&
        badBase.items.last.isDiscount &&
        badBase.reviewWarnings.isNotEmpty,
  );
  final badRate = parse('TEST CHICKEN 9.75\n(9.75@50.00%) -3.90');
  check(
    'A conflicting discount rate requires review',
    money(badRate.items.first.price, 9.75) &&
        badRate.items.last.isDiscount &&
        badRate.reviewWarnings.isNotEmpty,
  );
  final rounded = parse('TEST YOGURT 2.49\n(2.49@50.00%) -1.25');
  check(
    'Half-cent percentage deduction follows printed rounded deduction',
    rounded.items.length == 1 && money(rounded.items.single.price, 1.24),
  );
  check(
    'Missing geometry safely preserves original OCR text',
    reconstruct([const ReceiptOcrFragment(text: 'unknown', corners: [])]) ==
        'fallback',
  );
  stdout.writeln('\n$checks geometry and discount checks passed.');
}

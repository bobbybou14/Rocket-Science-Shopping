import 'dart:io';

import 'package:rocket_science_shopping/service/ocr_repair_service.dart';
import 'package:rocket_science_shopping/service/receipt_parser_service.dart';

void check(String label, bool passed) {
  if (!passed) throw StateError('FAIL: $label');
  stdout.writeln('PASS: $label');
}

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final text = File(
    '${root.path}/test/fixtures/save_on_foods_card_saving.txt',
  ).readAsStringSync();
  ParsedReceipt parse(String text) =>
      ReceiptParserService.parse(OcrRepairService.repair(text));

  final receipt = parse(text);
  check(
    'Store recognized from website when header is damaged',
    receipt.storeName == 'Save-On-Foods',
  );
  check(
    'Nine receipt rows without unit rate or points as purchases',
    receipt.items.length == 9,
  );
  final chips = receipt.items.singleWhere(
    (item) => item.name.contains('Chips'),
  );
  check('Card saving applied once', chips.price == 4.49 && chips.quantity == 1);
  final apples = receipt.items.singleWhere(
    (item) => item.name.contains('APPLE'),
  );
  check(
    'Apple weight attached to the printed extended price',
    apples.quantity == 0.725 && apples.price == 4.78 && apples.isWeightedItem,
  );
  final cloth = receipt.items.singleWhere(
    (item) => item.name.contains('CLOTH'),
  );
  check(
    'Free cloth quantity retained',
    cloth.quantity == 2 && cloth.price == 0,
  );
  final cents = receipt.items.fold<int>(
    0,
    (sum, item) => sum + (item.price * 100).round(),
  );
  check(
    'Items reconcile to the printed subtotal',
    cents == 5435 && receipt.subtotal == 54.35,
  );
  check(
    'GST, PST and total preserved',
    receipt.tax == 1.21 && receipt.total == 55.56,
  );

  final mismatched = parse(
    r'CHIPS 5.99'
    '\n'
    r'Card $4.49 Save -0.50',
  );
  check(
    'Conflicting card discount does not change the product and needs review',
    mismatched.items.first.price == 5.99 &&
        mismatched.items.last.isDiscount &&
        mismatched.reviewWarnings.isNotEmpty,
  );
  final distant = parse(
    r'CHIPS 4.99'
    '\n'
    r'Card Pts Earned 125'
    '\n'
    r'Card $4.49 Save -0.50',
  );
  check(
    'Card discount does not link across another line',
    distant.items.first.price == 4.99 && distant.reviewWarnings.isNotEmpty,
  );
  final badWeight = parse(
    r'APPLE 4.78'
    '\n'
    r'0.725 lb @ $6.59/kg',
  );
  check(
    'Incompatible units leave the printed line price intact',
    badWeight.items.single.price == 4.78 &&
        !badWeight.items.single.isWeightedItem &&
        badWeight.reviewWarnings.isNotEmpty,
  );
}

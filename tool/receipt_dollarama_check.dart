import 'dart:io';

import 'package:rocket_science_shopping/service/ocr_repair_service.dart';
import 'package:rocket_science_shopping/service/receipt_parser_service.dart';

ParsedReceipt parse(String text) =>
    ReceiptParserService.parse(OcrRepairService.repair(text));

void check(String label, bool passed) {
  if (!passed) throw StateError('FAIL: $label');
  stdout.writeln('PASS: $label');
}

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final text = File(
    '${root.path}/test/fixtures/dollarama_split_items.txt',
  ).readAsStringSync();
  final receipt = parse(text);
  check(
    'All six items survive the HST registration header',
    receipt.items.length == 6,
  );
  check('Dollarama store recognized', receipt.storeName == 'Dollarama');
  final first = receipt.items[0];
  final second = receipt.items[1];
  check(
    'Panasonic description, barcode, and price stay together',
    first.name.startsWith('PANASONIC') &&
        first.name.contains('885170435797') &&
        first.price == 2.61,
  );
  check(
    'AAA description, leading-zero barcode, and price stay together',
    second.name.startsWith('BATTERY AAA') &&
        second.name.contains('064547963679') &&
        second.price == 1.65,
  );
  check(
    'Every line price matches the receipt',
    receipt.items.map((item) => item.price.toStringAsFixed(2)).join(',') ==
        '2.61,1.65,4.25,3.00,2.25,4.50',
  );
  check(
    'Printed subtotal, HST, and total reconcile',
    receipt.subtotal == 18.26 &&
        receipt.tax == 2.37 &&
        receipt.total == 20.63 &&
        receipt.reviewWarnings.isEmpty,
  );
  check(
    'Barcode-price line cannot attach across a skipped line',
    parse(
          text.replaceFirst(
            '885170435797 2.61 H',
            'TRANSACTION REFERENCE\n885170435797 2.61 H',
          ),
        ).items.length ==
        5,
  );
  check(
    'A real tax amount remains a tax amount',
    parse('DOLLARAMA\nITEM 5.00\nSUBTOTAL 5.00\nHST 0.65\nTOTAL 5.65').tax ==
        0.65,
  );
}

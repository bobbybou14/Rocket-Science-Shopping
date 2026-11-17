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
    '${root.path}/test/fixtures/foodland_spaced_summary.txt',
  ).readAsStringSync();
  final receipt = parse(text);
  stdout.writeln(
    'Rows: ${receipt.items.length}, tax: ${receipt.tax}, total: ${receipt.total}',
  );
  check('Ten products and two deposits survive', receipt.items.length == 12);
  check(
    'Both pasta sauces remain products',
    receipt.items
            .where((item) => item.name.toLowerCase().startsWith('pstasauce'))
            .length ==
        2,
  );
  check(
    'Both deposits remain ten cents',
    receipt.items
            .where(
              (item) =>
                  item.name.toLowerCase().contains('deposit') &&
                  item.price == 0.10,
            )
            .length ==
        2,
  );
  check(
    'Repeated decimal separator repaired in cheese price',
    receipt.items
            .singleWhere((item) => item.name.startsWith('Cheese Shreds'))
            .price ==
        5.97,
  );
  check(
    'Savings lines create no deductions',
    receipt.items.every(
      (item) => !item.isDiscount && !item.name.toUpperCase().contains('SAVED'),
    ),
  );
  final cents = receipt.items.fold(
    0,
    (sum, item) => sum + (item.price * 100).round(),
  );
  check(
    'Items reconcile to the printed subtotal',
    cents == 3838 && receipt.subtotal == 38.38,
  );
  check(
    'Printed summary amounts corroborate spaced tax and total',
    receipt.tax == 0.78 && receipt.total == 39.16 && receipt.totalWasRecovered,
  );
  check('Foodland header recognized', receipt.storeName == 'Foodland');
  final conflict = parse(text.replaceFirst('TOTAL \$39 16', 'TOTAL \$39 17'));
  check('Conflicting damaged summary stays unresolved', conflict.total == 0);
  final fadedText = text
      .replaceFirst(r'TOTAL $39 16', r'TOTAL $39')
      .replaceFirst(r'MasterCard TENDER $6', 'MasterCard TENDER (6');
  final faded = parse(fadedText);
  check(
    'Faded scan recovers tax and total using the intact subtotal and visible dollars',
    faded.items.length == 12 &&
        faded.subtotal == 38.38 &&
        faded.tax == 0.78 &&
        faded.total == 39.16 &&
        faded.totalWasRecovered &&
        faded.reviewWarnings.any(
          (warning) => warning.contains('Total calculated'),
        ),
  );
  check(
    'A different printed dollar amount blocks recovery',
    parse(fadedText.replaceFirst(r'TOTAL $39', r'TOTAL $40')).total == 0,
  );
  check(
    'A mismatched item sum blocks recovery',
    parse(
          fadedText.replaceFirst(
            r'Tortilla Plain $4.99',
            r'Tortilla Plain $4.89',
          ),
        ).total ==
        0,
  );
  check(
    'A conflicting readable payment blocks recovery',
    parse(
          fadedText.replaceFirst('MasterCard TENDER (6', 'MasterCard 39.17'),
        ).total ==
        0,
  );
  check(
    'Missing tax cannot be assumed to be zero',
    parse(fadedText.replaceFirst(r'TOTAL TAX $0 78', 'TOTAL TAX')).total == 0,
  );
  final misreadText = text
      .replaceFirst(r'YOU SAVED $1.00', r'YOU SAVFD $1.00')
      .replaceFirst(r'TOTAL TAX $0 78', r'TOTAL TAX $o 78')
      .replaceFirst(r'MasterCard TENDER $6', r'MasterCard TENDER $ l 6');
  final misread = parse(misreadText);
  check(
    'Misread savings annotation does not add a dollar to the item subtotal',
    misread.items.length == 12 &&
        misread.items.fold(
              0,
              (sum, item) => sum + (item.price * 100).round(),
            ) ==
            3838,
  );
  check(
    'Letter o in summary tax is recovered when the printed figures agree',
    misread.subtotal == 38.38 && misread.tax == 0.78 && misread.total == 39.16,
  );
  check(
    'Letter o does not allow a conflicting summary to be accepted',
    parse(misreadText.replaceFirst(r'TOTAL $39 16', r'TOTAL $39 17')).total ==
        0,
  );
  final centsOnlyText = fadedText
      .replaceFirst(r'TOTAL TAX $0 78', r'TOTAL TAX $78')
      .replaceFirst('MasterCard TENDER (6', r'MasterCard TENDER $6')
      .replaceFirst(r'Cash CHANGE $0.00', 'Cash CHANGE 80.00');
  final centsOnly = parse(centsOnlyText);
  check(
    'Tax digits without a decimal recover against the subtotal and visible total',
    centsOnly.items.length == 12 &&
        centsOnly.subtotal == 38.38 &&
        centsOnly.tax == 0.78 &&
        centsOnly.total == 39.16 &&
        centsOnly.totalWasRecovered,
  );
  check(
    'Cents-only recovery requires a matching subtotal and total dollars',
    parse(
              centsOnlyText.replaceFirst(
                r'SUBTOTAL $38.38',
                r'SUBTOTAL $38.37',
              ),
            ).total ==
            0 &&
        parse(centsOnlyText.replaceFirst(r'TOTAL $39', r'TOTAL $40')).total ==
            0,
  );
  check(
    'Cents-only recovery does not override readable tax or a conflicting payment',
    parse(
              centsOnlyText.replaceFirst(
                r'TOTAL TAX $78',
                r'GST $0.10'
                    '\n'
                    r'TOTAL TAX $78',
              ),
            ).tax ==
            0.10 &&
        parse(
              centsOnlyText.replaceFirst(
                r'MasterCard TENDER $6',
                'MasterCard 39.17',
              ),
            ).total ==
            0,
  );
  final detailed = parse(
    'SUBTOTAL 10.00\nGST 0.50\nPST 0.70\nTOTAL TAX 1.20\nTOTAL 11.20',
  );
  check(
    'Tax summary does not double count component taxes',
    detailed.tax == 1.20,
  );
}

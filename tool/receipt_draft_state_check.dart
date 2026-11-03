import 'dart:io';

import 'package:rocket_science_shopping/models/shopping_trip.dart';

void main() {
  void check(String label, bool condition) {
    if (!condition) throw StateError('FAIL: $label');
    stdout.writeln('PASS: $label');
  }

  const item = ShoppingTripItem(
    id: '',
    shoppingTripId: '',
    rawReceiptName: 'ZERO CHERRY SF.D H',
    unitPrice: 0,
    lineTotal: 0,
    requiresReview: true,
    priceNeedsReview: true,
    sourceLine: 'ZERO CHERRY SF.D H .98',
  );
  final accepted = item.copyWith(requiresReview: false);
  check(
    'Bulk acceptance cannot accept a missing price',
    accepted.priceNeedsReview && accepted.requiresReview,
  );
  final selected = item.copyWith(confidenceScore: 100, requiresReview: false);
  check(
    'Product selection cannot accept a missing price',
    selected.priceNeedsReview && selected.requiresReview,
  );
  final edited = item.copyWith(
    priceNeedsReview: false,
    requiresReview: false,
    unitPrice: 7.98,
    lineTotal: 7.98,
  );
  check(
    'An explicit amount edit can resolve the price',
    !edited.priceNeedsReview &&
        !edited.requiresReview &&
        edited.lineTotal == 7.98,
  );
  check(
    'Copying retains the original incomplete OCR text',
    edited.sourceLine == 'ZERO CHERRY SF.D H .98',
  );
  check(
    'Draft-only fields do not introduce database columns',
    !edited.toMap().containsKey('price_needs_review') &&
        !edited.toMap().containsKey('source_line'),
  );
  stdout.writeln('\n5 draft-state checks passed.');
}

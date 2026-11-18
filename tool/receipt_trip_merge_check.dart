import 'dart:io';

import 'package:rocket_science_shopping/models/shopping_trip.dart';
import 'package:rocket_science_shopping/service/receipt_trip_match_service.dart';

void check(String label, bool condition) {
  if (!condition) throw StateError('FAIL: $label');
  stdout.writeln('PASS: $label');
}

void main() {
  final date = DateTime(2026, 11, 18, 12);
  final receipt = ShoppingTrip(
    id: '',
    storeId: 'branch-a',
    storeName: 'Food Basics',
    city: 'London',
    province: 'Ontario',
    purchaseDate: date,
    subtotal: 18,
    tax: 2,
    total: 20,
  );
  final live = receipt.copyWith(
    id: 'live',
    source: 'live_shopping',
    subtotal: 16,
    tax: 1.9,
    total: 17.9,
    purchaseDate: DateTime(2026, 11, 18, 9),
  );
  bool candidate(ShoppingTrip saved) =>
      ReceiptTripMatchService.isCandidate(receipt, saved);

  check(
    'Live trip remains a candidate when checkout prices differ',
    candidate(live),
  );
  check(
    'Different item counts do not hide an existing visit',
    candidate(
      live.copyWith(
        items: [
          const ShoppingTripItem(
            id: '',
            shoppingTripId: '',
            rawReceiptName: 'one line',
            unitPrice: 1,
            lineTotal: 1,
          ),
        ],
      ),
    ),
  );
  check(
    'Another branch is not offered',
    !candidate(live.copyWith(storeId: 'branch-b')),
  );
  check(
    'Another day is not offered',
    !candidate(live.copyWith(purchaseDate: DateTime(2026, 11, 17))),
  );
  check(
    'Older live trips with missing branch IDs can be selected',
    candidate(live.copyWith(storeId: '', city: '')),
  );
  check(
    'Legacy store names tolerate spaces and punctuation',
    candidate(live.copyWith(storeId: '', storeName: 'Food-Basics')),
  );
  check(
    'Legacy trips in another known city are excluded',
    !candidate(live.copyWith(storeId: '', city: 'Toronto')),
  );
  check(
    'A different legacy chain is excluded',
    !candidate(live.copyWith(storeId: '', storeName: 'Sobeys')),
  );
  check(
    'Repeated scans can attach to a trip already updated by a receipt',
    candidate(live.copyWith(source: 'receipt')),
  );
  check(
    'Two visits remain separate choices',
    candidate(live) && candidate(live.copyWith(id: 'second-visit')),
  );
  check(
    'Existing trip is not offered as its own duplicate',
    !ReceiptTripMatchService.isCandidate(receipt.copyWith(id: live.id), live),
  );
  check(
    'UTC timestamps use the local purchase day',
    candidate(live.copyWith(purchaseDate: live.purchaseDate.toUtc())),
  );
  const deposit = ShoppingTripItem(
    id: '',
    shoppingTripId: '',
    rawReceiptName: 'Deposit',
    unitPrice: 1.5,
    lineTotal: 1.5,
    isPostSubtotalDeposit: true,
    priceNeedsReview: true,
    sourceLine: '1.50 Deposit',
  );
  final copied = deposit.copyWith(shoppingTripId: 'saved');
  check(
    'Reassigning trip retains unresolved deposit state',
    copied.shoppingTripId == 'saved' &&
        copied.isPostSubtotalDeposit &&
        copied.priceNeedsReview &&
        copied.sourceLine == deposit.sourceLine,
  );
  check(
    'Existing trip serialization retains database column names',
    live.toMap()['source'] == 'live_shopping' &&
        !live.toMap().containsKey('id'),
  );
  check(
    'Earlier live timestamps without an offset retain their calendar date',
    candidate(
      live.copyWith(
        storeId: '',
        city: '',
        purchaseDate: DateTime.utc(2026, 11, 18, 1),
      ),
    ),
  );
  stdout.writeln('15 receipt trip merge checks passed.');
}

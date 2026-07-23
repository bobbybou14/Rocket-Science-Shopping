import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shopping_trip.dart';

class PriceUpdateResult {
  final int inserted;
  final int skipped;
  final List<String> skippedItems;

  const PriceUpdateResult({
    required this.inserted,
    required this.skipped,
    required this.skippedItems,
  });
}

class PriceUpdateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<PriceUpdateResult> updatePricesFromShoppingTrip(
    ShoppingTrip shoppingTrip,
  ) async {
    int inserted = 0;
    int skipped = 0;

    final skippedItems = <String>[];
    final storeName = shoppingTrip.storeName.trim();

    for (final item in shoppingTrip.items) {
      final barcode = item.barcode.trim();

      final canUpdatePrice =
          barcode.isNotEmpty &&
          storeName.isNotEmpty &&
          !item.requiresReview &&
          item.confidenceScore >= 75 &&
          item.unitPrice > 0;

      if (!canUpdatePrice) {
        skipped++;
        skippedItems.add(item.rawReceiptName);
        continue;
      }

      try {
        await _supabase.from('prices').insert({
          'barcode': barcode,
          'store': storeName,
          'province': shoppingTrip.province,
          'city': shoppingTrip.city,
          'price': item.unitPrice,
          'currency': 'CAD',
          'store_id': shoppingTrip.storeId.isEmpty
              ? null
              : shoppingTrip.storeId,
          'source': 'receipt',
          'notes': 'Automatically added from shopping trip ${shoppingTrip.id}.',
        });

        inserted++;
      } catch (_) {
        skipped++;
        skippedItems.add(item.rawReceiptName);
      }
    }

    return PriceUpdateResult(
      inserted: inserted,
      skipped: skipped,
      skippedItems: skippedItems,
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/receipt.dart';
import '../models/shopping_trip.dart';
import 'receipt_builder_service.dart';
import 'receipt_trip_match_service.dart';
import 'shopping_trip_service.dart';

class ReceiptTripSaveResult {
  final ShoppingTrip trip;
  final bool alreadySaved;

  const ReceiptTripSaveResult({required this.trip, required this.alreadySaved});
}

class ReceiptTripSaveService {
  const ReceiptTripSaveService._();

  static Future<bool> isSaved(String receiptId) async {
    final row = await Supabase.instance.client
        .from('receipts')
        .select('shopping_trip_id')
        .eq('id', receiptId)
        .single();
    return row['shopping_trip_id'] != null;
  }

  static Future<ReceiptTripSaveResult> save({
    required Receipt receipt,
    required ShoppingTrip trip,
    String? mergeTripId,
  }) async {
    final day = ReceiptTripMatchService.startOfDay(trip.purchaseDate);
    final nextDay = DateTime(day.year, day.month, day.day + 1);
    final snapshots = ReceiptBuilderService.buildItemsFromReviewedTrip(
      receiptId: receipt.id,
      reviewedTrip: trip,
    );
    final response = await Supabase.instance.client.rpc(
      'save_receipt_shopping_trip',
      params: {
        'p_receipt_id': receipt.id,
        'p_trip': {
          ...trip.toMap(),
          'purchase_date': trip.purchaseDate.toUtc().toIso8601String(),
          'purchase_day': day.toIso8601String().split('T').first,
        },
        'p_items': trip.items.map((item) => item.toMap()).toList(),
        'p_receipt_items': snapshots.map((item) => item.toMap()).toList(),
        'p_merge_trip_id': mergeTripId,
        'p_day_start': day.toUtc().toIso8601String(),
        'p_day_end': nextDay.toUtc().toIso8601String(),
      },
    );
    final result = Map<String, dynamic>.from(response as Map);
    return ReceiptTripSaveResult(
      trip: await ShoppingTripService.getShoppingTrip(
        result['trip_id'] as String,
      ),
      alreadySaved: result['already_saved'] == true,
    );
  }
}

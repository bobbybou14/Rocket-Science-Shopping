import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/shopping_trip.dart';

class ShoppingTripService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<ShoppingTrip> saveShoppingTrip(
    ShoppingTrip shoppingTrip,
  ) async {
    final tripResponse = await _supabase
        .from('shopping_trips')
        .insert(shoppingTrip.toMap())
        .select()
        .single();

    final savedTrip = ShoppingTrip.fromMap(tripResponse);

    if (shoppingTrip.items.isNotEmpty) {
      final itemRows = shoppingTrip.items.map((item) {
        return item.copyWithShoppingTripId(savedTrip.id).toMap();
      }).toList();

      await _supabase.from('shopping_trip_items').insert(itemRows);
    }

    return getShoppingTrip(savedTrip.id);
  }

  static Future<List<ShoppingTrip>> getShoppingTrips() async {
    final response = await _supabase
        .from('shopping_trips')
        .select()
        .order('purchase_date', ascending: false);

    return response
        .map<ShoppingTrip>((row) => ShoppingTrip.fromMap(row))
        .toList();
  }

  static Future<ShoppingTrip> getShoppingTrip(String shoppingTripId) async {
    final tripResponse = await _supabase
        .from('shopping_trips')
        .select()
        .eq('id', shoppingTripId)
        .single();

    final itemResponse = await _supabase
        .from('shopping_trip_items')
        .select('''
          *,
          products (
            barcode,
            name,
            brand,
            category,
            size,
            image_url,
            taxable
          )
        ''')
        .eq('shopping_trip_id', shoppingTripId)
        .order('created_at');

    final items = itemResponse.map<ShoppingTripItem>((row) {
      Product? product;

      final productMap = row['products'];
      if (productMap is Map<String, dynamic>) {
        product = Product.fromMap(productMap);
      } else if (productMap is Map) {
        product = Product.fromMap(Map<String, dynamic>.from(productMap));
      }

      return ShoppingTripItem.fromMap(row, product: product);
    }).toList();

    return ShoppingTrip.fromMap(tripResponse, items: items);
  }

  static Future<void> deleteShoppingTrip(String shoppingTripId) async {
    await _supabase.from('shopping_trips').delete().eq('id', shoppingTripId);
  }
}

extension ShoppingTripItemCopy on ShoppingTripItem {
  ShoppingTripItem copyWithShoppingTripId(String shoppingTripId) {
    return ShoppingTripItem(
      id: id,
      shoppingTripId: shoppingTripId,
      rawReceiptName: rawReceiptName,
      product: product,
      barcode: barcode,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      confidenceScore: confidenceScore,
      requiresReview: requiresReview,
      createdAt: createdAt,
    );
  }
}

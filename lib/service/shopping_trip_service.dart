import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/shopping_trip.dart';

class ShoppingTripService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw StateError(
        'A signed-in user is required to access shopping trips.',
      );
    }

    return userId;
  }

  static Future<ShoppingTrip> saveShoppingTrip(
    ShoppingTrip shoppingTrip,
  ) async {
    final userId = _requireUserId();

    final tripResponse = await _supabase
        .from('shopping_trips')
        .insert({...shoppingTrip.toMap(), 'user_id': userId})
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
    final userId = _requireUserId();

    final response = await _supabase
        .from('shopping_trips')
        .select()
        .eq('user_id', userId)
        .order('purchase_date', ascending: false);

    final loadedTrips = response
        .map<ShoppingTrip>(
          (row) => ShoppingTrip.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();

    debugPrint(
      'ShoppingTripService.getShoppingTrips returned '
      '${loadedTrips.length} trip(s).',
    );

    for (final trip in loadedTrips) {
      debugPrint(
        'Dashboard trip: '
        'id=${trip.id}, '
        'store=${trip.storeName}, '
        'purchaseDate=${trip.purchaseDate.toIso8601String()}, '
        'subtotal=${trip.subtotal}, '
        'total=${trip.total}, '
        'status=${trip.processingStatus}',
      );
    }

    return loadedTrips;
  }

  static Future<ShoppingTrip> getShoppingTrip(String shoppingTripId) async {
    final userId = _requireUserId();

    final tripResponse = await _supabase
        .from('shopping_trips')
        .select()
        .eq('id', shoppingTripId)
        .eq('user_id', userId)
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

      return ShoppingTripItem.fromMap(
        Map<String, dynamic>.from(row),
        product: product,
      );
    }).toList();

    return ShoppingTrip.fromMap(
      Map<String, dynamic>.from(tripResponse),
      items: items,
    );
  }

  static Future<List<ShoppingTrip>> findPossibleDuplicates(
    ShoppingTrip shoppingTrip,
  ) async {
    final userId = _requireUserId();
    final purchaseDate = shoppingTrip.purchaseDate;
    final startOfDay = DateTime(
      purchaseDate.year,
      purchaseDate.month,
      purchaseDate.day,
    );
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    var query = _supabase
        .from('shopping_trips')
        .select()
        .eq('user_id', userId)
        .eq('store_id', shoppingTrip.storeId)
        .gte('purchase_date', startOfDay.toIso8601String())
        .lt('purchase_date', startOfNextDay.toIso8601String())
        .eq('total', shoppingTrip.total);

    if (shoppingTrip.id.trim().isNotEmpty) {
      query = query.neq('id', shoppingTrip.id);
    }

    final response = await query.order('purchase_date', ascending: false);

    final duplicates = <ShoppingTrip>[];

    for (final row in response) {
      final candidateMap = Map<String, dynamic>.from(row);
      final candidateId = candidateMap['id']?.toString() ?? '';

      if (candidateId.isEmpty) {
        continue;
      }

      final candidate = await getShoppingTrip(candidateId);

      final sameSubtotal = _moneyMatches(
        candidate.subtotal,
        shoppingTrip.subtotal,
      );

      final sameTax = _moneyMatches(candidate.tax, shoppingTrip.tax);

      final sameTotal = _moneyMatches(candidate.total, shoppingTrip.total);

      final sameItemCount = candidate.items.length == shoppingTrip.items.length;

      if (sameSubtotal && sameTax && sameTotal && sameItemCount) {
        duplicates.add(candidate);
      }
    }

    debugPrint(
      'ShoppingTripService.findPossibleDuplicates found '
      '${duplicates.length} possible duplicate(s).',
    );

    return duplicates;
  }

  static Future<void> deleteShoppingTrip(String shoppingTripId) async {
    final userId = _requireUserId();
    final cleanedShoppingTripId = shoppingTripId.trim();

    if (cleanedShoppingTripId.isEmpty) {
      throw ArgumentError('A shopping trip ID is required for deletion.');
    }

    // RLS permits deleting child rows only when the signed-in user owns
    // the corresponding shopping trip.
    await _supabase
        .from('shopping_trip_items')
        .delete()
        .eq('shopping_trip_id', cleanedShoppingTripId);

    await _supabase
        .from('shopping_trips')
        .delete()
        .eq('id', cleanedShoppingTripId)
        .eq('user_id', userId);
  }

  static bool _moneyMatches(double first, double second) {
    return (first - second).abs() < 0.01;
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

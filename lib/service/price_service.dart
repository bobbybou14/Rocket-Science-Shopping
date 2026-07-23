import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/price.dart';

class PriceService {
  static final _client = Supabase.instance.client;

  /// Returns all prices for a product, sorted lowest to highest.
  static Future<List<Price>> getPricesForProduct(String barcode) async {
    try {
      final response = await _client
          .from('prices')
          .select()
          .eq('barcode', barcode)
          .order('price');

      return response.map<Price>((price) => Price.fromMap(price)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves a new price.
  static Future<void> savePrice(Price price) async {
    try {
      await _client.from('prices').insert(price.toMap());
    } catch (_) {
      return;
    }
  }

  /// Returns the cheapest known price.
  static Future<Price?> getLowestPrice(String barcode) async {
    final prices = await getPricesForProduct(barcode);

    if (prices.isEmpty) {
      return null;
    }

    return prices.first;
  }
}

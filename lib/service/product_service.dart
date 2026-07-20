import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class ProductService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<Product>> getProducts() async {
  try {
    final response = await _supabase
        .from('products')
        .select()
        .order('name');

    return response
        .map<Product>((item) => Product.fromMap(item))
        .toList();
  } catch (_) {
    return [];
  }
}

  static Future<CartItem?> findByBarcode(String barcode) async {
  try {
    final response = await _supabase
        .from('products')
        .select()
        .eq('barcode', barcode)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final product = Product.fromMap(response);

    final priceResponse = await _supabase
        .from('prices')
        .select('price')
        .eq('barcode', barcode)
        .order('updated_at', ascending: false)
        .limit(1);

    double price = 0;

    if (priceResponse.isNotEmpty) {
      price =
          (priceResponse.first['price'] as num).toDouble();
    }

    return CartItem(
      product: product,
      price: price,
    );
  } catch (_) {
    return null;
   }
 }
}
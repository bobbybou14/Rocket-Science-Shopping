import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class ProductService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static Future<int> getProductCount() async {
    return await _supabase.from('products').count(CountOption.exact);
  }

  static Future<List<Product>> getProducts() async {
    try {
      final response = await _supabase.from('products').select().order('name');

      return response.map<Product>((item) => Product.fromMap(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Product>> findReceiptCandidates(
    String searchText, {
    int limit = 200,
  }) async {
    final query = searchText.trim();

    if (query.isEmpty) return [];

    if (limit < 1 || limit > 300) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 300');
    }

    final response = await _supabase.rpc(
      'find_receipt_product_candidates',
      params: {'p_search': query, 'p_limit': limit},
    );

    return (response as List)
        .map((item) => Product.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static Future<List<Product>> searchProducts({
    String search = '',
    String category = 'All',
    int offset = 0,
    int pageSize = 50,
  }) async {
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must be zero or greater');
    }

    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Must be between 1 and 100',
      );
    }

    final response = await _supabase.rpc(
      'search_catalog_products',
      params: {
        'p_search': search.trim(),
        'p_category': category,
        'p_offset': offset,
        'p_limit': pageSize + 1,
      },
    );

    return (response as List)
        .map((item) => Product.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static List<String> _barcodeCandidates(String barcode) {
    final value = barcode.trim();

    if (value.isEmpty) return [];

    final candidates = <String>{value};

    // Only expand valid 12-, 13-, or 14-digit GTINs.
    // Short, custom, and invalid codes retain exact matching.
    if (!RegExp(r'^[0-9]{12,14}$').hasMatch(value)) {
      return candidates.toList();
    }

    var sum = 0;
    var weight = 3;

    for (var index = value.length - 2; index >= 0; index--) {
      sum += int.parse(value[index]) * weight;
      weight = weight == 3 ? 1 : 3;
    }

    final expectedCheckDigit = (10 - sum % 10) % 10;

    if (expectedCheckDigit != int.parse(value[value.length - 1])) {
      return candidates.toList();
    }

    final gtin14 = value.padLeft(14, '0');

    if (gtin14.startsWith('0')) {
      candidates.add(gtin14.substring(1));
    }

    if (gtin14.startsWith('00')) {
      candidates.add(gtin14.substring(2));
    }

    candidates.add(gtin14);

    return candidates.toList();
  }

  static Future<Product?> getProductByBarcode(String barcode) async {
    final candidates = _barcodeCandidates(barcode);

    if (candidates.isEmpty) return null;

    final rows = await _supabase
        .from('products')
        .select()
        .inFilter('barcode', candidates);

    // Prefer the exact scanned value, then equivalent forms.
    for (final candidate in candidates) {
      for (final row in rows) {
        if (row['barcode'] == candidate) {
          return Product.fromMap(row);
        }
      }
    }

    return null;
  }

  static Future<CartItem?> findByBarcode(String barcode) async {
    try {
      final product = await getProductByBarcode(barcode);

      if (product == null) return null;

      final priceResponse = await _supabase
          .from('prices')
          .select('price')
          .eq('barcode', product.barcode)
          .order('created_at', ascending: false, nullsFirst: false)
          .order('id', ascending: false)
          .limit(1);

      double price = 0;

      if (priceResponse.isNotEmpty) {
        price = (priceResponse.first['price'] as num).toDouble();
      }

      return CartItem(product: product, price: price);
    } catch (_) {
      return null;
    }
  }

  static Future<Product> updateProduct(Product product) async {
    final response = await _supabase
        .from('products')
        .update(product.toMap())
        .eq('barcode', product.barcode)
        .select()
        .single();

    return Product.fromMap(response);
  }
}

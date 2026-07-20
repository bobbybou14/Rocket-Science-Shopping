import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class FavoriteProduct {
  final String id;
  final String barcode;
  final DateTime createdAt;
  final Product? product;

  const FavoriteProduct({
    required this.id,
    required this.barcode,
    required this.createdAt,
    this.product,
  });

  factory FavoriteProduct.fromMap(Map<String, dynamic> map) {
    Product? product;

    final productData = map['products'];

    if (productData is Map<String, dynamic>) {
      product = Product.fromMap(productData);
    } else if (productData is Map) {
      product = Product.fromMap(Map<String, dynamic>.from(productData));
    }

    return FavoriteProduct(
      id: map['id']?.toString() ?? '',
      barcode: map['barcode']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      product: product,
    );
  }
}

class FavoritesService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<FavoriteProduct>> getFavorites() async {
    try {
      final response = await _supabase
          .from('favorites')
          .select('''
            id,
            barcode,
            created_at,
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
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(
        response,
      ).map(FavoriteProduct.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isFavorite(String barcode) async {
    final cleanedBarcode = barcode.trim();

    if (cleanedBarcode.isEmpty) {
      return false;
    }

    try {
      final response = await _supabase
          .from('favorites')
          .select('id')
          .eq('barcode', cleanedBarcode)
          .limit(1);

      return response.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> addFavorite(Product product) async {
    final barcode = product.barcode.trim();

    if (barcode.isEmpty) {
      throw Exception('This product does not have a valid barcode.');
    }

    final alreadyFavorite = await isFavorite(barcode);

    if (alreadyFavorite) {
      return;
    }

    await _supabase.from('favorites').insert({'barcode': barcode});
  }

  static Future<void> removeFavorite(String barcode) async {
    final cleanedBarcode = barcode.trim();

    if (cleanedBarcode.isEmpty) {
      return;
    }

    try {
      await _supabase.from('favorites').delete().eq('barcode', cleanedBarcode);
    } catch (_) {
      return;
    }
  }

  static Future<bool> toggleFavorite(Product product) async {
    final currentlyFavorite = await isFavorite(product.barcode);

    if (currentlyFavorite) {
      await removeFavorite(product.barcode);
      return false;
    }

    await addFavorite(product);
    return true;
  }
}

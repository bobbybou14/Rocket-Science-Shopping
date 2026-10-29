import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class GroceryListItem {
  final String id;
  final String name;
  final String? barcode;
  final double quantity;
  final bool isChecked;
  final Product? product;

  const GroceryListItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.quantity,
    required this.isChecked,
    required this.product,
  });

  factory GroceryListItem.fromMap(Map<String, dynamic> map) {
    final productData = map['products'];

    return GroceryListItem(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      barcode: map['barcode']?.toString(),
      quantity: (map['quantity'] as num).toDouble(),
      isChecked: map['is_checked'] == true,
      product: productData is Map
          ? Product.fromMap(Map<String, dynamic>.from(productData))
          : null,
    );
  }
}

class GroceryListService {
  GroceryListService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static String _requireUserId() {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in to access your grocery list.');
    }

    return userId;
  }

  static void _validateQuantity(double quantity) {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero.');
    }
  }

  static Future<List<GroceryListItem>> getItems() async {
    final userId = _requireUserId();
    final items = <GroceryListItem>[];
    const pageSize = 500;
    var offset = 0;

    while (true) {
      final response = await _client
          .from('grocery_list_items')
          .select('*, products(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);

      if (response.isEmpty) break;

      items.addAll(
        response.map(
          (row) => GroceryListItem.fromMap(Map<String, dynamic>.from(row)),
        ),
      );

      offset += response.length;
    }

    return items;
  }

  static Future<void> addManualItem({
    required String name,
    double quantity = 1,
  }) async {
    final userId = _requireUserId();
    final cleanedName = name.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError('Enter an item name.');
    }

    _validateQuantity(quantity);

    await _client.from('grocery_list_items').insert({
      'user_id': userId,
      'name': cleanedName,
      'quantity': quantity,
    });
  }

  static Future<void> addProduct({
    required Product product,
    double quantity = 1,
  }) async {
    final userId = _requireUserId();
    final barcode = product.barcode.trim();

    if (barcode.isEmpty || product.name.trim().isEmpty) {
      throw ArgumentError('The product needs a name and barcode.');
    }

    _validateQuantity(quantity);

    final existing = await _client
        .from('grocery_list_items')
        .select('id')
        .eq('user_id', userId)
        .eq('barcode', barcode)
        .maybeSingle();

    if (existing != null) {
      throw StateError(
        'This product is already on your grocery list. '
        'Change its quantity in the list.',
      );
    }

    try {
      await _client.from('grocery_list_items').insert({
        'user_id': userId,
        'barcode': barcode,
        'name': product.name.trim(),
        'quantity': quantity,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw StateError('This product is already on your grocery list.');
      }

      rethrow;
    }
  }

  static Future<void> updateItem({
    required String id,
    required String name,
    required double quantity,
  }) async {
    final userId = _requireUserId();
    final cleanedName = name.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError('Enter an item name.');
    }

    _validateQuantity(quantity);

    await _client
        .from('grocery_list_items')
        .update({'name': cleanedName, 'quantity': quantity})
        .eq('user_id', userId)
        .eq('id', id);
  }

  static Future<void> setChecked({
    required String id,
    required bool isChecked,
  }) async {
    final userId = _requireUserId();

    await _client
        .from('grocery_list_items')
        .update({'is_checked': isChecked})
        .eq('user_id', userId)
        .eq('id', id);
  }

  static Future<void> deleteItem(String id) async {
    final userId = _requireUserId();

    await _client
        .from('grocery_list_items')
        .delete()
        .eq('user_id', userId)
        .eq('id', id);
  }

  static Future<void> clearCheckedItems() async {
    final userId = _requireUserId();

    await _client
        .from('grocery_list_items')
        .delete()
        .eq('user_id', userId)
        .eq('is_checked', true);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/product_alias.dart';

class ProductAliasService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<ProductAlias>> getAliases() async {
    try {
      final response = await _supabase
          .from('product_aliases')
          .select()
          .order('times_used', ascending: false);

      return response
          .map<ProductAlias>((item) => ProductAlias.fromMap(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<ProductAlias>> getAliasesForReceiptItems(
    Iterable<String> receiptItemNames,
  ) async {
    final normalizedNames = receiptItemNames
        .map(normalizeAlias)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    final aliases = <ProductAlias>[];
    const batchSize = 100;

    for (var start = 0; start < normalizedNames.length; start += batchSize) {
      final end = start + batchSize > normalizedNames.length
          ? normalizedNames.length
          : start + batchSize;

      final batch = normalizedNames.sublist(start, end);

      final response = await _supabase
          .from('product_aliases')
          .select()
          .inFilter('normalized_alias', batch)
          .order('times_used', ascending: false);

      aliases.addAll(
        response.map<ProductAlias>((item) => ProductAlias.fromMap(item)),
      );
    }

    return aliases;
  }

  static Product? findMatchingProduct({
    required String receiptItemName,
    required List<ProductAlias> aliases,
    required List<Product> products,
  }) {
    final normalizedReceiptName = normalizeAlias(receiptItemName);

    if (normalizedReceiptName.isEmpty) {
      return null;
    }

    ProductAlias? matchingAlias;

    for (final alias in aliases) {
      if (alias.normalizedAlias == normalizedReceiptName) {
        matchingAlias = alias;
        break;
      }
    }

    if (matchingAlias == null || matchingAlias.productBarcode.isEmpty) {
      return null;
    }

    for (final product in products) {
      if (product.barcode == matchingAlias.productBarcode) {
        return product;
      }
    }

    return null;
  }

  static Future<bool> saveAlias({
    required String alias,
    required Product product,
  }) async {
    final trimmedAlias = alias.trim();
    final normalizedAlias = normalizeAlias(trimmedAlias);

    if (trimmedAlias.isEmpty ||
        normalizedAlias.isEmpty ||
        product.barcode.isEmpty) {
      return false;
    }

    try {
      final existing = await _supabase
          .from('product_aliases')
          .select()
          .eq('normalized_alias', normalizedAlias)
          .maybeSingle();

      final existingTimesUsed = existing == null
          ? 0
          : _toInt(existing['times_used']);

      await _supabase.from('product_aliases').upsert({
        'alias': trimmedAlias,
        'normalized_alias': normalizedAlias,
        'product_barcode': product.barcode,
        'product_name': product.name,
        'times_used': existingTimesUsed + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'normalized_alias');

      return true;
    } catch (_) {
      return false;
    }
  }

  static String normalizeAlias(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

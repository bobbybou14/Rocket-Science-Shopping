import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class BasketItemRequest {
  final Product product;
  final double quantity;

  const BasketItemRequest({
    required this.product,
    this.quantity = 1,
  });
}

class BasketStoreItemResult {
  final String barcode;
  final String productName;
  final double quantity;
  final double? unitPrice;
  final double? lineTotal;
  final bool hasPrice;

  const BasketStoreItemResult({
    required this.barcode,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.hasPrice,
  });
}

class BasketStoreComparison {
  final String storeId;
  final String storeName;
  final String city;
  final String province;
  final double total;
  final int pricedItems;
  final int missingItems;
  final List<BasketStoreItemResult> items;

  const BasketStoreComparison({
    required this.storeId,
    required this.storeName,
    required this.city,
    required this.province,
    required this.total,
    required this.pricedItems,
    required this.missingItems,
    required this.items,
  });

  bool get isComplete => missingItems == 0;
}

class BasketComparisonResult {
  final List<BasketStoreComparison> stores;
  final BasketStoreComparison? cheapestCompleteStore;
  final double potentialSavings;

  const BasketComparisonResult({
    required this.stores,
    required this.cheapestCompleteStore,
    required this.potentialSavings,
  });
}

class BasketComparisonService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<BasketComparisonResult> compareBasket(
    List<BasketItemRequest> basketItems,
  ) async {
    if (basketItems.isEmpty) {
      return const BasketComparisonResult(
        stores: [],
        cheapestCompleteStore: null,
        potentialSavings: 0,
      );
    }

    final storeResponse = await _supabase
        .from('stores')
        .select()
        .order('name');

    final stores = List<Map<String, dynamic>>.from(storeResponse);

    final comparisons = <BasketStoreComparison>[];

    for (final store in stores) {
      final storeId = store['id']?.toString() ?? '';
      
      if (storeId.isEmpty) {
        continue;
      }
      
      final storeName = store['name']?.toString() ?? 'Unknown Store';
      final city = store['city']?.toString() ?? '';
      final province = store['province']?.toString() ?? '';

      double total = 0;
      int pricedItems = 0;
      int missingItems = 0;

      final itemResults = <BasketStoreItemResult>[];

      for (final basketItem in basketItems) {
        final barcode = basketItem.product.barcode;
        final quantity =
            basketItem.quantity <= 0 ? 1.0 : basketItem.quantity;

        final priceResponse = await _supabase
            .from('prices')
            .select('price')
            .eq('barcode', barcode)
            .eq('store_id', storeId)
            .order('created_at', ascending: false)
            .limit(1);

        double? unitPrice;

        if (priceResponse.isNotEmpty) {
          final rawPrice = priceResponse.first['price'];

          if (rawPrice is num) {
            unitPrice = rawPrice.toDouble();
          } else {
            unitPrice = double.tryParse(rawPrice?.toString() ?? '');
          }
        }

        if (unitPrice == null || unitPrice <= 0) {
          missingItems++;

          itemResults.add(
            BasketStoreItemResult(
              barcode: barcode,
              productName: _productDisplayName(basketItem.product),
              quantity: quantity,
              unitPrice: null,
              lineTotal: null,
              hasPrice: false,
            ),
          );

          continue;
        }

        final lineTotal = unitPrice * quantity;

        total += lineTotal;
        pricedItems++;

        itemResults.add(
          BasketStoreItemResult(
            barcode: barcode,
            productName: _productDisplayName(basketItem.product),
            quantity: quantity,
            unitPrice: unitPrice,
            lineTotal: lineTotal,
            hasPrice: true,
          ),
        );
      }

      comparisons.add(
        BasketStoreComparison(
          storeId: storeId,
          storeName: storeName,
          city: city,
          province: province,
          total: total,
          pricedItems: pricedItems,
          missingItems: missingItems,
          items: itemResults,
        ),
      );
    }

    comparisons.sort((a, b) {
      if (a.isComplete && !b.isComplete) return -1;
      if (!a.isComplete && b.isComplete) return 1;

      if (a.isComplete && b.isComplete) {
        return a.total.compareTo(b.total);
      }

      final missingComparison =
          a.missingItems.compareTo(b.missingItems);

      if (missingComparison != 0) {
        return missingComparison;
      }

      return a.total.compareTo(b.total);
    });

    final completeStores = comparisons
        .where((comparison) => comparison.isComplete)
        .toList();

    BasketStoreComparison? cheapestCompleteStore;
    double potentialSavings = 0;

    if (completeStores.isNotEmpty) {
      cheapestCompleteStore = completeStores.first;

      if (completeStores.length > 1) {
        final mostExpensiveCompleteStore = completeStores.reduce(
          (current, next) =>
              next.total > current.total ? next : current,
        );

        potentialSavings =
            mostExpensiveCompleteStore.total -
            cheapestCompleteStore.total;
      }
    }

    return BasketComparisonResult(
      stores: comparisons,
      cheapestCompleteStore: cheapestCompleteStore,
      potentialSavings: potentialSavings,
    );
  }

  static String _productDisplayName(Product product) {
    final parts = [
      product.brand,
      product.name,
      product.size,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return product.barcode;
    }

    return parts.join(' ');
  }
}
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import 'package:flutter/foundation.dart';

class BasketItemRequest {
  final Product product;
  final double quantity;

  const BasketItemRequest({required this.product, this.quantity = 1});
}

class BasketStoreItemResult {
  final String barcode;
  final String productName;
  final double quantity;
  final double? unitPrice;
  final double? lineTotal;
  final bool hasPrice;
  final double? measurementQuantity;
  final String? advertisedUnit;
  final String? normalizedUnit;
  final double? normalizedUnitPrice;
  final bool isBestUnitValue;

  const BasketStoreItemResult({
    required this.barcode,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.hasPrice,
    this.measurementQuantity,
    this.advertisedUnit,
    this.normalizedUnit,
    this.normalizedUnitPrice,
    this.isBestUnitValue = false,
  });

  bool get hasNormalizedUnitPrice =>
      normalizedUnitPrice != null &&
      normalizedUnitPrice!.isFinite &&
      normalizedUnitPrice! > 0 &&
      normalizedUnit != null &&
      normalizedUnit!.trim().isNotEmpty;

  BasketStoreItemResult copyWith({bool? isBestUnitValue}) {
    return BasketStoreItemResult(
      barcode: barcode,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      hasPrice: hasPrice,
      measurementQuantity: measurementQuantity,
      advertisedUnit: advertisedUnit,
      normalizedUnit: normalizedUnit,
      normalizedUnitPrice: normalizedUnitPrice,
      isBestUnitValue: isBestUnitValue ?? this.isBestUnitValue,
    );
  }
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

  int get bestValueItems => items.where((item) => item.isBestUnitValue).length;

  int get normalizedItems =>
      items.where((item) => item.hasNormalizedUnitPrice).length;

  BasketStoreComparison copyWith({List<BasketStoreItemResult>? items}) {
    return BasketStoreComparison(
      storeId: storeId,
      storeName: storeName,
      city: city,
      province: province,
      total: total,
      pricedItems: pricedItems,
      missingItems: missingItems,
      items: items ?? this.items,
    );
  }
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

  bool get hasCompleteStore => cheapestCompleteStore != null;
}

class BasketComparisonService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const BasketComparisonResult _emptyResult = BasketComparisonResult(
    stores: [],
    cheapestCompleteStore: null,
    potentialSavings: 0,
  );

  static Future<BasketComparisonResult> compareBasket(
    List<BasketItemRequest> basketItems,
  ) async {
    final validBasketItems = _prepareBasketItems(basketItems);

    if (validBasketItems.isEmpty) {
      return _emptyResult;
    }

    final stores = await _loadStores();

    if (stores.isEmpty) {
      return _emptyResult;
    }

    final storeIds = stores
        .map((store) => _stringValue(store['id']))
        .toSet()
        .toList();

    final barcodes = validBasketItems
        .map((item) => item.product.barcode.trim())
        .toSet()
        .toList();

    final latestPrices = await _loadLatestPrices(
      barcodes: barcodes,
      storeIds: storeIds,
    );

    final comparisons = stores.map((store) {
      return _buildStoreComparison(
        store: store,
        basketItems: validBasketItems,
        latestPrices: latestPrices,
      );
    }).toList();

    final rankedComparisons = _markBestNormalizedUnitValues(comparisons);
    rankedComparisons.sort(_compareStores);

    final completeStores = rankedComparisons
        .where((comparison) => comparison.isComplete)
        .toList();

    BasketStoreComparison? cheapestCompleteStore;
    double potentialSavings = 0;

    if (completeStores.isNotEmpty) {
      cheapestCompleteStore = completeStores.first;

      if (completeStores.length > 1) {
        final mostExpensiveCompleteStore = completeStores.reduce(
          (current, next) => next.total > current.total ? next : current,
        );

        potentialSavings =
            mostExpensiveCompleteStore.total - cheapestCompleteStore.total;
      }
    }

    return BasketComparisonResult(
      stores: rankedComparisons,
      cheapestCompleteStore: cheapestCompleteStore,
      potentialSavings: potentialSavings,
    );
  }

  static List<BasketItemRequest> _prepareBasketItems(
    List<BasketItemRequest> basketItems,
  ) {
    final productsByBarcode = <String, Product>{};
    final quantitiesByBarcode = <String, double>{};

    for (final basketItem in basketItems) {
      final barcode = basketItem.product.barcode.trim();

      if (barcode.isEmpty) continue;

      final quantity = basketItem.quantity.isFinite && basketItem.quantity > 0
          ? basketItem.quantity
          : 1.0;

      productsByBarcode.putIfAbsent(barcode, () => basketItem.product);

      quantitiesByBarcode.update(
        barcode,
        (current) => current + quantity,
        ifAbsent: () => quantity,
      );
    }

    return productsByBarcode.entries.map((entry) {
      return BasketItemRequest(
        product: entry.value,
        quantity: quantitiesByBarcode[entry.key] ?? 1,
      );
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _loadStores() async {
    const pageSize = 500;
    final storesById = <String, Map<String, dynamic>>{};
    String? afterId;

    while (true) {
      var query = _supabase.from('stores').select('id, name, city, province');

      if (afterId != null) {
        query = query.gt('id', afterId);
      }

      final response = await query.order('id', ascending: true).limit(pageSize);
      final rows = List<Map<String, dynamic>>.from(response);
      debugPrint(
        'Basket store page: ${rows.length} rows; '
        'afterId=$afterId; '
        'lastId=${rows.isEmpty ? "none" : rows.last["id"]}',
      );

      if (rows.isEmpty) break;

      for (final row in rows) {
        final id = _stringValue(row['id']);

        if (id.isEmpty) {
          throw StateError('A store was returned without an ID.');
        }

        storesById[id] = row;
      }

      final lastId = _stringValue(rows.last['id']);

      if (lastId == afterId) {
        throw StateError('Store loading did not advance to the next page.');
      }

      afterId = lastId;
    }

    final stores = storesById.values.toList();
    debugPrint('Basket stores loaded: ${stores.length}');
    stores.sort((first, second) {
      final nameComparison = _stringValue(
        first['name'],
      ).toLowerCase().compareTo(_stringValue(second['name']).toLowerCase());

      if (nameComparison != 0) return nameComparison;

      return _stringValue(first['id']).compareTo(_stringValue(second['id']));
    });

    return stores;
  }

  static Future<Map<String, Map<String, dynamic>>> _loadLatestPrices({
    required List<String> barcodes,
    required List<String> storeIds,
  }) async {
    if (barcodes.isEmpty || storeIds.isEmpty) {
      return {};
    }

    final uniqueBarcodes = barcodes
        .map((barcode) => barcode.trim())
        .where((barcode) => barcode.isNotEmpty)
        .toSet()
        .toList();

    final allowedStoreIds = storeIds.toSet();
    final latestPrices = <String, Map<String, dynamic>>{};

    const barcodeBatchSize = 100;
    const pageSize = 500;

    for (
      var start = 0;
      start < uniqueBarcodes.length;
      start += barcodeBatchSize
    ) {
      final end = start + barcodeBatchSize > uniqueBarcodes.length
          ? uniqueBarcodes.length
          : start + barcodeBatchSize;

      final batch = uniqueBarcodes.sublist(start, end);
      final batchBarcodes = batch.toSet();

      String? afterBarcode;
      String? afterStoreId;

      while (true) {
        final response = await _supabase.rpc(
          'get_basket_latest_prices',
          params: {
            'p_barcodes': batch,
            'p_after_barcode': afterBarcode,
            'p_after_store_id': afterStoreId,
            'p_limit': pageSize,
          },
        );

        final rows = List<Map<String, dynamic>>.from(response);

        if (rows.isEmpty) break;

        for (final row in rows) {
          final barcode = _stringValue(row['barcode']);
          final storeId = _stringValue(row['store_id']);

          if (barcode.isEmpty || storeId.isEmpty) {
            throw StateError(
              'A basket price was returned without a barcode or store ID.',
            );
          }

          if (!batchBarcodes.contains(barcode) ||
              !allowedStoreIds.contains(storeId)) {
            continue;
          }

          final key = _priceKey(barcode: barcode, storeId: storeId);

          latestPrices[key] = row;
        }

        final lastBarcode = _stringValue(rows.last['barcode']);
        final lastStoreId = _stringValue(rows.last['store_id']);

        if (lastBarcode == afterBarcode && lastStoreId == afterStoreId) {
          throw StateError('Price loading did not advance to the next page.');
        }

        afterBarcode = lastBarcode;
        afterStoreId = lastStoreId;
      }
    }

    return latestPrices;
  }

  static BasketStoreComparison _buildStoreComparison({
    required Map<String, dynamic> store,
    required List<BasketItemRequest> basketItems,
    required Map<String, Map<String, dynamic>> latestPrices,
  }) {
    final storeId = _stringValue(store['id']);
    final storedName = _stringValue(store['name']);
    final storeName = storedName.isEmpty ? 'Unknown Store' : storedName;

    double total = 0;
    int pricedItems = 0;
    int missingItems = 0;

    final itemResults = <BasketStoreItemResult>[];

    for (final basketItem in basketItems) {
      final barcode = basketItem.product.barcode.trim();
      final quantity = basketItem.quantity.isFinite && basketItem.quantity > 0
          ? basketItem.quantity
          : 1.0;

      final key = _priceKey(barcode: barcode, storeId: storeId);

      final priceMap = latestPrices[key];
      final shelfPrice = _positiveDouble(priceMap?['price']);

      if (priceMap == null || shelfPrice == null) {
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

      final lineTotal = shelfPrice * quantity;
      total += lineTotal;
      pricedItems++;

      itemResults.add(
        BasketStoreItemResult(
          barcode: barcode,
          productName: _productDisplayName(basketItem.product),
          quantity: quantity,
          unitPrice: shelfPrice,
          lineTotal: lineTotal,
          hasPrice: true,
          measurementQuantity: _positiveDouble(
            priceMap['measurement_quantity'],
          ),
          advertisedUnit: _nullableString(priceMap['advertised_unit']),
          normalizedUnit: _nullableString(priceMap['normalized_unit']),
          normalizedUnitPrice: _positiveDouble(
            priceMap['normalized_unit_price'],
          ),
        ),
      );
    }

    return BasketStoreComparison(
      storeId: storeId,
      storeName: storeName,
      city: _stringValue(store['city']),
      province: _stringValue(store['province']),
      total: total,
      pricedItems: pricedItems,
      missingItems: missingItems,
      items: itemResults,
    );
  }

  static List<BasketStoreComparison> _markBestNormalizedUnitValues(
    List<BasketStoreComparison> comparisons,
  ) {
    final lowestPrices = <String, double>{};

    for (final comparison in comparisons) {
      for (final item in comparison.items) {
        if (!item.hasNormalizedUnitPrice) continue;

        final key = _unitComparisonKey(
          barcode: item.barcode,
          normalizedUnit: item.normalizedUnit!,
        );

        final candidate = item.normalizedUnitPrice!;
        final currentLowest = lowestPrices[key];

        if (currentLowest == null || candidate < currentLowest) {
          lowestPrices[key] = candidate;
        }
      }
    }

    return comparisons.map((comparison) {
      final updatedItems = comparison.items.map((item) {
        if (!item.hasNormalizedUnitPrice) {
          return item;
        }

        final key = _unitComparisonKey(
          barcode: item.barcode,
          normalizedUnit: item.normalizedUnit!,
        );

        final lowestPrice = lowestPrices[key];

        if (lowestPrice == null) {
          return item;
        }

        return item.copyWith(
          isBestUnitValue: _approximatelyEqual(
            item.normalizedUnitPrice!,
            lowestPrice,
          ),
        );
      }).toList();

      return comparison.copyWith(items: updatedItems);
    }).toList();
  }

  static int _compareStores(
    BasketStoreComparison first,
    BasketStoreComparison second,
  ) {
    if (first.isComplete && !second.isComplete) return -1;
    if (!first.isComplete && second.isComplete) return 1;

    if (first.isComplete && second.isComplete) {
      return first.total.compareTo(second.total);
    }

    final missingComparison = first.missingItems.compareTo(second.missingItems);

    if (missingComparison != 0) return missingComparison;

    final pricedComparison = second.pricedItems.compareTo(first.pricedItems);

    if (pricedComparison != 0) return pricedComparison;

    return first.total.compareTo(second.total);
  }

  static String _priceKey({required String barcode, required String storeId}) {
    return '${barcode.trim()}::${storeId.trim()}';
  }

  static String _unitComparisonKey({
    required String barcode,
    required String normalizedUnit,
  }) {
    return '${barcode.trim()}::${normalizedUnit.trim().toLowerCase()}';
  }

  static bool _approximatelyEqual(double first, double second) {
    const tolerance = 0.000001;
    return (first - second).abs() <= tolerance;
  }

  static double? _positiveDouble(dynamic value) {
    final parsed = _toDouble(value);

    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _nullableString(dynamic value) {
    final parsed = _stringValue(value);
    return parsed.isEmpty ? null : parsed;
  }

  static String _productDisplayName(Product product) {
    final parts = [
      product.brand,
      product.name,
      product.size,
    ].where((value) => value.trim().isNotEmpty).toList();

    return parts.isEmpty ? product.barcode : parts.join(' ');
  }
}

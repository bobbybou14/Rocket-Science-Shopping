import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class BasketItemRequest {
  final Product product;
  final double quantity;

  const BasketItemRequest({required this.product, this.quantity = 1});
}

class BasketStoreItemResult {
  final String barcode;
  final String productName;
  final double quantity;

  /// Actual package or shelf price.
  final double? unitPrice;

  /// Actual shelf-price total multiplied by the requested basket quantity.
  final double? lineTotal;

  final bool hasPrice;

  /// Quantity used when calculating the normalized unit price.
  final double? measurementQuantity;

  /// Unit printed or advertised for the product, such as g, kg, mL, or L.
  final String? advertisedUnit;

  /// Standard comparison unit, such as kg, L, or each.
  final String? normalizedUnit;

  /// Comparable price per normalized unit.
  final double? normalizedUnitPrice;

  /// True when this store has the lowest comparable normalized price for
  /// this product among the stores included in the comparison.
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

  static Future<BasketComparisonResult> compareBasket(
    List<BasketItemRequest> basketItems,
  ) async {
    final validBasketItems = _prepareBasketItems(basketItems);

    if (validBasketItems.isEmpty) {
      return _emptyResult;
    }

    final storeResponse = await _supabase
        .from('stores')
        .select('id, name, city, province')
        .order('name');

    final stores = List<Map<String, dynamic>>.from(
      storeResponse,
    ).where((store) => _stringValue(store['id']).isNotEmpty).toList();

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

    final comparisonsWithValueRanking = _markBestNormalizedUnitValues(
      comparisons,
    );

    comparisonsWithValueRanking.sort(_compareStores);

    final completeStores = comparisonsWithValueRanking
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
      stores: comparisonsWithValueRanking,
      cheapestCompleteStore: cheapestCompleteStore,
      potentialSavings: potentialSavings,
    );
  }

  static const BasketComparisonResult _emptyResult = BasketComparisonResult(
    stores: [],
    cheapestCompleteStore: null,
    potentialSavings: 0,
  );

  /// Removes invalid basket entries and combines duplicate barcodes.
  ///
  /// Combining duplicates ensures a product appearing more than once in the
  /// basket is represented by one request with the total requested quantity.
  static List<BasketItemRequest> _prepareBasketItems(
    List<BasketItemRequest> basketItems,
  ) {
    final productsByBarcode = <String, Product>{};
    final quantitiesByBarcode = <String, double>{};

    for (final basketItem in basketItems) {
      final barcode = basketItem.product.barcode.trim();

      if (barcode.isEmpty) {
        continue;
      }

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

  /// Loads all relevant price records in one request and retains only the
  /// newest record for each barcode and store combination.
  static Future<Map<String, Map<String, dynamic>>> _loadLatestPrices({
    required List<String> barcodes,
    required List<String> storeIds,
  }) async {
    if (barcodes.isEmpty || storeIds.isEmpty) {
      return {};
    }

    final response = await _supabase
        .from('prices')
        .select(
          'barcode, '
          'store_id, '
          'price, '
          'measurement_quantity, '
          'advertised_unit, '
          'normalized_unit, '
          'normalized_unit_price, '
          'created_at',
        )
        .inFilter('barcode', barcodes)
        .inFilter('store_id', storeIds)
        .order('created_at', ascending: false);

    final priceRows = List<Map<String, dynamic>>.from(response);
    final latestPrices = <String, Map<String, dynamic>>{};

    for (final priceRow in priceRows) {
      final barcode = _stringValue(priceRow['barcode']);
      final storeId = _stringValue(priceRow['store_id']);

      if (barcode.isEmpty || storeId.isEmpty) {
        continue;
      }

      final key = _priceKey(barcode: barcode, storeId: storeId);

      // Rows are ordered newest first, so the first matching row is the
      // current price for that barcode and store.
      latestPrices.putIfAbsent(key, () => priceRow);
    }

    return latestPrices;
  }

  static BasketStoreComparison _buildStoreComparison({
    required Map<String, dynamic> store,
    required List<BasketItemRequest> basketItems,
    required Map<String, Map<String, dynamic>> latestPrices,
  }) {
    final storeId = _stringValue(store['id']);
    final storeName = _stringValue(store['name']).isEmpty
        ? 'Unknown Store'
        : _stringValue(store['name']);

    final city = _stringValue(store['city']);
    final province = _stringValue(store['province']);

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
      city: city,
      province: province,
      total: total,
      pricedItems: pricedItems,
      missingItems: missingItems,
      items: itemResults,
    );
  }

  /// Marks the lowest normalized unit price for each barcode and unit.
  ///
  /// Prices are only compared when both the barcode and normalized unit match.
  /// This prevents dollars per kilogram from being compared with dollars per
  /// litre or dollars per item.
  static List<BasketStoreComparison> _markBestNormalizedUnitValues(
    List<BasketStoreComparison> comparisons,
  ) {
    final lowestPrices = <String, double>{};

    for (final comparison in comparisons) {
      for (final item in comparison.items) {
        if (!item.hasNormalizedUnitPrice) {
          continue;
        }

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
    if (first.isComplete && !second.isComplete) {
      return -1;
    }

    if (!first.isComplete && second.isComplete) {
      return 1;
    }

    if (first.isComplete && second.isComplete) {
      return first.total.compareTo(second.total);
    }

    final missingComparison = first.missingItems.compareTo(second.missingItems);

    if (missingComparison != 0) {
      return missingComparison;
    }

    final pricedComparison = second.pricedItems.compareTo(first.pricedItems);

    if (pricedComparison != 0) {
      return pricedComparison;
    }

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
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _nullableString(dynamic value) {
    final parsed = _stringValue(value);

    if (parsed.isEmpty) {
      return null;
    }

    return parsed;
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

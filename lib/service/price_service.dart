import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/price.dart';
import 'unit_conversion_service.dart';

class PriceService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Returns all known prices for a product.
  ///
  /// Comparable normalized prices are sorted lowest to highest.
  /// Older records without normalized pricing fall back to their
  /// original advertised price.
  static Future<List<Price>> getPricesForProduct(String barcode) async {
    try {
      final response = await _client
          .from('prices')
          .select()
          .eq('barcode', barcode);

      final prices = response
          .map<Price>((item) => Price.fromMap(item))
          .toList();

      prices.sort(_comparePrices);

      return prices;
    } catch (error, stackTrace) {
      debugPrint('Could not load prices for barcode $barcode: $error');
      debugPrintStack(stackTrace: stackTrace);

      return [];
    }
  }

  /// Returns only the newest known price for each exact store.
  ///
  /// Historical records remain available through [getPricesForProduct].
  static Future<List<Price>> getCurrentPricesForProduct(String barcode) async {
    final allPrices = await getPricesForProduct(barcode);
    final latestPriceByStore = <String, Price>{};

    for (final price in allPrices) {
      final storeKey = _storeKey(price);
      final existingPrice = latestPriceByStore[storeKey];

      if (existingPrice == null || _isNewerPrice(price, existingPrice)) {
        latestPriceByStore[storeKey] = price;
      }
    }

    final currentPrices = latestPriceByStore.values.toList();
    currentPrices.sort(_comparePrices);
    return currentPrices;
  }

  /// Saves a new price.
  ///
  /// If normalized pricing was not already supplied, this method
  /// calculates it from the advertised unit, measurement quantity,
  /// and normalized unit.
  static Future<void> savePrice(Price price) async {
    final preparedPrice = _prepareForSave(price);

    try {
      await _client.from('prices').insert(preparedPrice.toMap());

      debugPrint(
        'Price saved for barcode ${preparedPrice.barcode}: '
        '\$${preparedPrice.price.toStringAsFixed(2)}.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Could not save price for barcode '
        '${preparedPrice.barcode}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// Returns the cheapest known comparable price.
  static Future<Price?> getLowestPrice(String barcode) async {
    final prices = await getPricesForProduct(barcode);

    if (prices.isEmpty) {
      return null;
    }

    return prices.first;
  }

  /// Returns the newest known price for a product at one exact store.
  static Future<Price?> getLatestPriceForStore({
    required String barcode,
    required String storeId,
  }) async {
    final cleanBarcode = barcode.trim();
    final cleanStoreId = storeId.trim();

    if (cleanBarcode.isEmpty || cleanStoreId.isEmpty) {
      return null;
    }

    try {
      final response = await _client
          .from('prices')
          .select()
          .eq('barcode', cleanBarcode)
          .eq('store_id', cleanStoreId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Price.fromMap(response);
    } catch (error, stackTrace) {
      debugPrint(
        'Could not load store price for barcode '
        '$cleanBarcode at store $cleanStoreId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      return null;
    }
  }

  /// Returns the newest known price for a product.
  static Future<Price?> getLatestPrice(String barcode) async {
    try {
      final response = await _client
          .from('prices')
          .select()
          .eq('barcode', barcode)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Price.fromMap(response);
    } catch (error, stackTrace) {
      debugPrint(
        'Could not load the latest price for barcode '
        '$barcode: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      return null;
    }
  }

  static Price _prepareForSave(Price price) {
    final existingNormalizedPrice = price.normalizedUnitPrice;

    if (existingNormalizedPrice != null && existingNormalizedPrice > 0) {
      return price;
    }

    if (price.price <= 0 || price.measurementQuantity <= 0) {
      return price;
    }

    try {
      final normalizedPrice = UnitConversionService.normalizeUnitPrice(
        totalPrice: price.price,
        quantity: price.measurementQuantity,
        advertisedUnit: price.advertisedUnit,
        normalizedUnit: price.normalizedUnit,
      );

      return Price(
        id: price.id,
        barcode: price.barcode,
        storeId: price.storeId,
        store: price.store,
        province: price.province,
        city: price.city,
        price: price.price,
        currency: price.currency,
        source: price.source,
        receiptId: price.receiptId,
        notes: price.notes,
        advertisedUnit: price.advertisedUnit,
        measurementQuantity: price.measurementQuantity,
        normalizedUnit: price.normalizedUnit,
        normalizedUnitPrice: normalizedPrice,
        isSale: price.isSale,
        regularPrice: price.regularPrice,
        saleStartDate: price.saleStartDate,
        saleEndDate: price.saleEndDate,
        promotionType: price.promotionType,
        createdAt: price.createdAt,
      );
    } on UnsupportedError catch (error) {
      debugPrint(
        'Price normalization was skipped for barcode '
        '${price.barcode}: $error',
      );

      return price;
    }
  }

  static String _storeKey(Price price) {
    final storeId = price.storeId?.trim();

    if (storeId != null && storeId.isNotEmpty) {
      return 'id:$storeId';
    }

    final store = price.store.trim().toLowerCase();
    final city = price.city.trim().toLowerCase();
    final province = price.province.trim().toLowerCase();

    return 'legacy:$store|$city|$province';
  }

  static bool _isNewerPrice(Price candidate, Price existing) {
    final candidateDate = candidate.createdAt;
    final existingDate = existing.createdAt;

    if (candidateDate == null) {
      return false;
    }

    if (existingDate == null) {
      return true;
    }

    return candidateDate.isAfter(existingDate);
  }

  static int _comparePrices(Price first, Price second) {
    final firstComparable = first.normalizedUnitPrice ?? first.price;

    final secondComparable = second.normalizedUnitPrice ?? second.price;

    return firstComparable.compareTo(secondComparable);
  }
}

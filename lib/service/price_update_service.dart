import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/shopping_trip.dart';
import 'price_calculation_service.dart';
import 'price_service.dart';

class PriceUpdateResult {
  final int inserted;
  final int skipped;
  final List<String> skippedItems;
  final List<String> errors;

  const PriceUpdateResult({
    required this.inserted,
    required this.skipped,
    required this.skippedItems,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;

  bool get hasInsertedPrices => inserted > 0;

  int get totalProcessed => inserted + skipped;
}

class PriceUpdateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Creates normalized price-history records from a completed shopping trip.
  ///
  /// Each eligible receipt item:
  /// 1. Is validated.
  /// 2. Is matched to its product record.
  /// 3. Is passed through PriceCalculationService.
  /// 4. Is saved through PriceService.
  static Future<PriceUpdateResult> updatePricesFromShoppingTrip(
    ShoppingTrip shoppingTrip,
  ) async {
    var inserted = 0;
    var skipped = 0;

    final skippedItems = <String>[];
    final errors = <String>[];

    final storeName = shoppingTrip.storeName.trim();
    final province = shoppingTrip.province.trim();
    final city = shoppingTrip.city.trim();

    for (final item in shoppingTrip.items) {
      final itemName = item.rawReceiptName.trim().isEmpty
          ? 'Unknown receipt item'
          : item.rawReceiptName.trim();

      final barcode = item.barcode.trim();

      final skipReason = _validateReceiptItem(
        barcode: barcode,
        storeName: storeName,
        requiresReview: item.requiresReview,
        confidenceScore: item.confidenceScore,
        unitPrice: item.unitPrice,
      );

      if (skipReason != null) {
        skipped++;

        final skippedMessage = '$itemName: $skipReason';
        skippedItems.add(skippedMessage);

        debugPrint('Price update skipped: $skippedMessage');
        continue;
      }

      Product? product;

      try {
        product = await _findProductByBarcode(barcode);
      } catch (error, stackTrace) {
        skipped++;

        final errorMessage =
            '$itemName ($barcode): product lookup failed: $error';

        skippedItems.add('$itemName: Product lookup failed.');
        errors.add(errorMessage);

        debugPrint(errorMessage);
        debugPrintStack(stackTrace: stackTrace);
        continue;
      }

      if (product == null) {
        skipped++;

        final skippedMessage =
            '$itemName: No product was found for barcode $barcode.';

        skippedItems.add(skippedMessage);

        debugPrint('Price update skipped: $skippedMessage');
        continue;
      }

      try {
        final calculatedPrice = PriceCalculationService.createPrice(
          product: product,
          price: item.unitPrice,
          store: storeName,
          storeId: shoppingTrip.storeId.trim().isEmpty
              ? null
              : shoppingTrip.storeId.trim(),
          province: province,
          city: city,
          currency: 'CAD',
          source: 'receipt',
          receiptId: shoppingTrip.id.trim().isEmpty
              ? null
              : shoppingTrip.id.trim(),
          notes:
              'Automatically added from shopping trip '
              '${shoppingTrip.id}.',
        );

        await PriceService.savePrice(calculatedPrice);

        inserted++;

        final normalizedDescription =
            calculatedPrice.normalizedUnitPrice == null
            ? ''
            : ', normalized to '
                  '\$${calculatedPrice.normalizedUnitPrice!.toStringAsFixed(2)}'
                  '/${calculatedPrice.normalizedUnit.name}';

        debugPrint(
          'Price inserted: '
          '$itemName, barcode $barcode, '
          '\$${item.unitPrice.toStringAsFixed(2)}'
          '$normalizedDescription.',
        );
      } on ArgumentError catch (error, stackTrace) {
        skipped++;

        final errorMessage =
            '$itemName ($barcode): price validation failed: $error';

        skippedItems.add('$itemName: Price validation failed.');
        errors.add(errorMessage);

        debugPrint(errorMessage);
        debugPrintStack(stackTrace: stackTrace);
      } catch (error, stackTrace) {
        skipped++;

        final errorMessage = '$itemName ($barcode): price save failed: $error';

        skippedItems.add('$itemName: Price could not be saved.');
        errors.add(errorMessage);

        debugPrint(errorMessage);
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    debugPrint(
      'Price update complete: '
      '$inserted inserted, '
      '$skipped skipped, '
      '${errors.length} errors.',
    );

    return PriceUpdateResult(
      inserted: inserted,
      skipped: skipped,
      skippedItems: skippedItems,
      errors: errors,
    );
  }

  static Future<Product?> _findProductByBarcode(String barcode) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('barcode', barcode)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Product.fromMap(response);
  }

  static String? _validateReceiptItem({
    required String barcode,
    required String storeName,
    required bool requiresReview,
    required double confidenceScore,
    required double unitPrice,
  }) {
    if (barcode.isEmpty) {
      return 'Missing barcode.';
    }

    if (storeName.isEmpty) {
      return 'Missing store name.';
    }

    if (requiresReview) {
      return 'Item still requires review.';
    }

    if (!confidenceScore.isFinite || confidenceScore < 75) {
      return 'Confidence score '
          '${confidenceScore.toStringAsFixed(0)} is below 75.';
    }

    if (!unitPrice.isFinite || unitPrice <= 0) {
      return 'Unit price must be greater than zero.';
    }

    return null;
  }
}

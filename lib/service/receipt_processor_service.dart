import '../models/receipt.dart';
import '../models/shopping_trip.dart';
import 'ocr_normalization_service.dart';
import 'ocr_repair_service.dart';
import 'ocr_service.dart';
import 'price_update_service.dart';
import 'receipt_builder_service.dart';
import 'receipt_intelligence_service.dart';
import 'receipt_service.dart';
import 'shopping_trip_builder_service.dart';
import 'shopping_trip_service.dart';

class ReceiptProcessorService {
  static Future<ReceiptReviewDraft> prepareReceipt({
    required Receipt receipt,
    required String imagePath,
    required String storeId,
    required String storeName,
    required String city,
    required String province,
  }) async {
    if (imagePath.trim().isEmpty) {
      throw const ReceiptProcessingException(
        'A receipt image path is required.',
      );
    }

    try {
      final rawText = await OcrService.extractTextFromImage(imagePath);
      final normalizedText = OcrNormalizationService.normalize(rawText);
      final repairedText = OcrRepairService.repair(normalizedText);

      if (repairedText.trim().isEmpty) {
        await ReceiptService.updateReceipt(
          _copyReceiptWithProcessingResult(
            receipt: receipt,
            processingStatus: 'ocr_failed',
            notes: 'No readable text was found on the receipt.',
          ),
        );

        throw const ReceiptProcessingException(
          'No readable text was found on the receipt.',
        );
      }

      final intelligenceResult =
          await ReceiptIntelligenceService.processRawText(repairedText);

      final shoppingTrip =
          ShoppingTripBuilderService.buildFromReceiptIntelligence(
            intelligenceResult: intelligenceResult,
            storeId: storeId,
            storeName: storeName,
            city: city,
            province: province,
          );

      await ReceiptService.updateReceipt(
        _copyReceiptWithProcessingResult(
          receipt: receipt,
          processingStatus: 'pending_review',
          notes:
              '${shoppingTrip.items.length} items were extracted and are waiting for review.',
        ),
      );

      return ReceiptReviewDraft(
        receipt: receipt,
        intelligenceResult: intelligenceResult,
        shoppingTrip: shoppingTrip,
      );
    } catch (error, stackTrace) {
      if (error is ReceiptProcessingException) {
        rethrow;
      }

      try {
        await ReceiptService.updateReceipt(
          _copyReceiptWithProcessingResult(
            receipt: receipt,
            processingStatus: 'failed',
            notes: 'Receipt preparation failed: $error',
          ),
        );
      } catch (_) {
        // Preserve the original preparation error.
      }

      throw ReceiptProcessingException(
        'Receipt preparation failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<ReceiptProcessingResult> completeReviewedReceipt({
    required Receipt receipt,
    required ShoppingTrip reviewedTrip,
    bool allowDuplicate = false,
  }) async {
    if (reviewedTrip.items.isEmpty) {
      throw const ReceiptProcessingException(
        'A reviewed receipt must contain at least one item.',
      );
    }

    if (reviewedTrip.items.any((item) => item.requiresReview)) {
      throw const ReceiptProcessingException(
        'All receipt items must be reviewed before confirmation.',
      );
    }

    try {
      final verifiedTrip = reviewedTrip.copyWith(processingStatus: 'verified');

      final possibleDuplicates =
          await ShoppingTripService.findPossibleDuplicates(verifiedTrip);

      if (possibleDuplicates.isNotEmpty && !allowDuplicate) {
        throw DuplicateReceiptException(possibleDuplicates: possibleDuplicates);
      }

      // 1. Save the reviewed shopping trip and its normalized items.
      final savedTrip = await ShoppingTripService.saveShoppingTrip(
        verifiedTrip,
      );

      // 2. Build and save the permanent receipt-item snapshot.
      final receiptItems = ReceiptBuilderService.buildItemsFromReviewedTrip(
        receiptId: receipt.id,
        reviewedTrip: savedTrip,
      );

      await ReceiptService.saveReceiptItems(receiptItems);

      // 3. Save the confirmed price observations.
      final priceResult = await PriceUpdateService.updatePricesFromShoppingTrip(
        savedTrip,
      );

      final productsFound = savedTrip.items.length;

      final productsMatched = savedTrip.items
          .where((item) => item.product != null)
          .length;

      // 4. Mark the receipt as fully processed.
      await ReceiptService.updateReceipt(
        Receipt(
          id: receipt.id,
          storeId: receipt.storeId,
          storeName: receipt.storeName,
          province: receipt.province,
          city: receipt.city,
          purchaseDate: savedTrip.purchaseDate,
          subtotal: savedTrip.subtotal,
          tax: savedTrip.tax,
          total: savedTrip.total,
          source: receipt.source,
          processingStatus: 'processed',
          personalDataRedacted: true,
          rawImageStored: receipt.rawImageStored,
          notes: _buildReceiptNotes(
            shoppingTripId: savedTrip.id,
            productsFound: productsFound,
            productsMatched: productsMatched,
            pricesUpdated: priceResult.inserted,
            reviewRequired: 0,
          ),
          createdAt: receipt.createdAt,
        ),
      );

      return ReceiptProcessingResult(
        receiptId: receipt.id,
        status: 'processed',
        personalDataRedacted: true,
        rawImageStored: receipt.rawImageStored,
        productsFound: productsFound,
        productsMatched: productsMatched,
        pricesUpdated: priceResult.inserted,
        shoppingTripId: savedTrip.id,
        reviewRequired: 0,
        message: _buildSuccessMessage(
          productsFound: productsFound,
          productsMatched: productsMatched,
          pricesUpdated: priceResult.inserted,
          reviewRequired: 0,
        ),
      );
    } on DuplicateReceiptException {
      rethrow;
    } catch (error, stackTrace) {
      try {
        await ReceiptService.updateReceipt(
          _copyReceiptWithProcessingResult(
            receipt: receipt,
            processingStatus: 'failed',
            notes: 'Saving the reviewed receipt failed: $error',
          ),
        );
      } catch (_) {
        // Preserve the original completion error.
      }

      throw ReceiptProcessingException(
        'Saving the reviewed receipt failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<ReceiptProcessingResult> processReceipt({
    required Receipt receipt,
    required String imagePath,
    required String storeId,
    required String storeName,
    required String city,
    required String province,
  }) async {
    if (imagePath.trim().isEmpty) {
      throw const ReceiptProcessingException(
        'A receipt image path is required.',
      );
    }

    try {
      // 1. Extract, normalize, and repair text from the receipt image.
      final rawText = await OcrService.extractTextFromImage(imagePath);
      final normalizedText = OcrNormalizationService.normalize(rawText);
      final repairedText = OcrRepairService.repair(normalizedText);

      if (repairedText.trim().isEmpty) {
        await ReceiptService.updateReceipt(
          _copyReceiptWithProcessingResult(
            receipt: receipt,
            processingStatus: 'ocr_failed',
            notes: 'No readable text was found on the receipt.',
          ),
        );

        return ReceiptProcessingResult(
          receiptId: receipt.id,
          status: 'ocr_failed',
          personalDataRedacted: true,
          rawImageStored: receipt.rawImageStored,
          productsFound: 0,
          productsMatched: 0,
          pricesUpdated: 0,
          shoppingTripId: '',
          reviewRequired: 0,
          message: 'No readable text was found on the receipt.',
        );
      }

      // 2. Parse the repaired text and match receipt items.
      final intelligenceResult =
          await ReceiptIntelligenceService.processRawText(repairedText);

      // 3. Build a shopping trip from the receipt results.
      final shoppingTrip =
          ShoppingTripBuilderService.buildFromReceiptIntelligence(
            intelligenceResult: intelligenceResult,
            storeId: storeId,
            storeName: storeName,
            city: city,
            province: province,
          );

      // 4. Save the shopping trip and its normalized items.
      final savedTrip = await ShoppingTripService.saveShoppingTrip(
        shoppingTrip,
      );

      // 5. Build and save the permanent receipt-item snapshot.
      final receiptItems = ReceiptBuilderService.buildItemsFromIntelligence(
        receiptId: receipt.id,
        intelligenceResult: intelligenceResult,
      );

      await ReceiptService.saveReceiptItems(receiptItems);

      // 6. Save high-confidence price observations.
      final priceResult = await PriceUpdateService.updatePricesFromShoppingTrip(
        savedTrip,
      );

      final parsedReceipt = intelligenceResult.parsedReceipt;

      final productsFound = parsedReceipt.items.length;

      final productsMatched = intelligenceResult.productMatches
          .where((match) => match.hasMatch)
          .length;

      final reviewRequired = intelligenceResult.reviewRequired;

      final status = reviewRequired > 0 ? 'pending_review' : 'processed';

      // 7. Update the original receipt with the processing results.
      await ReceiptService.updateReceipt(
        Receipt(
          id: receipt.id,
          storeId: receipt.storeId,
          storeName: receipt.storeName,
          province: receipt.province,
          city: receipt.city,
          purchaseDate: parsedReceipt.purchaseDate ?? receipt.purchaseDate,
          subtotal: parsedReceipt.subtotal,
          tax: parsedReceipt.tax,
          total: parsedReceipt.total,
          source: receipt.source,
          processingStatus: status,
          personalDataRedacted: true,
          rawImageStored: receipt.rawImageStored,
          notes: _buildReceiptNotes(
            shoppingTripId: savedTrip.id,
            productsFound: productsFound,
            productsMatched: productsMatched,
            pricesUpdated: priceResult.inserted,
            reviewRequired: reviewRequired,
          ),
          createdAt: receipt.createdAt,
        ),
      );

      return ReceiptProcessingResult(
        receiptId: receipt.id,
        status: status,
        personalDataRedacted: true,
        rawImageStored: receipt.rawImageStored,
        productsFound: productsFound,
        productsMatched: productsMatched,
        pricesUpdated: priceResult.inserted,
        shoppingTripId: savedTrip.id,
        reviewRequired: reviewRequired,
        message: _buildSuccessMessage(
          productsFound: productsFound,
          productsMatched: productsMatched,
          pricesUpdated: priceResult.inserted,
          reviewRequired: reviewRequired,
        ),
      );
    } on DuplicateReceiptException {
      rethrow;
    } catch (error, stackTrace) {
      try {
        await ReceiptService.updateReceipt(
          _copyReceiptWithProcessingResult(
            receipt: receipt,
            processingStatus: 'failed',
            notes: 'Saving the reviewed receipt failed: $error',
          ),
        );
      } catch (_) {
        // Preserve the original completion error.
      }

      throw ReceiptProcessingException(
        'Saving the reviewed receipt failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Receipt _copyReceiptWithProcessingResult({
    required Receipt receipt,
    required String processingStatus,
    required String notes,
  }) {
    return Receipt(
      id: receipt.id,
      storeId: receipt.storeId,
      storeName: receipt.storeName,
      province: receipt.province,
      city: receipt.city,
      purchaseDate: receipt.purchaseDate,
      subtotal: receipt.subtotal,
      tax: receipt.tax,
      total: receipt.total,
      source: receipt.source,
      processingStatus: processingStatus,
      personalDataRedacted: receipt.personalDataRedacted,
      rawImageStored: receipt.rawImageStored,
      notes: notes,
      createdAt: receipt.createdAt,
    );
  }

  static String _buildReceiptNotes({
    required String shoppingTripId,
    required int productsFound,
    required int productsMatched,
    required int pricesUpdated,
    required int reviewRequired,
  }) {
    return 'Shopping trip: $shoppingTripId. '
        '$productsFound receipt items found. '
        '$productsMatched products matched. '
        '$pricesUpdated prices updated. '
        '$reviewRequired items require review.';
  }

  static String _buildSuccessMessage({
    required int productsFound,
    required int productsMatched,
    required int pricesUpdated,
    required int reviewRequired,
  }) {
    if (reviewRequired > 0) {
      return 'Receipt processed. '
          '$productsFound items found, '
          '$productsMatched matched, '
          '$pricesUpdated prices updated, and '
          '$reviewRequired items require review.';
    }

    return 'Receipt processed successfully. '
        '$productsFound items found, '
        '$productsMatched matched, and '
        '$pricesUpdated prices updated.';
  }
}

class ReceiptReviewDraft {
  final Receipt receipt;
  final ReceiptIntelligenceResult intelligenceResult;
  final ShoppingTrip shoppingTrip;

  const ReceiptReviewDraft({
    required this.receipt,
    required this.intelligenceResult,
    required this.shoppingTrip,
  });
}

class ReceiptProcessingResult {
  final String receiptId;
  final String status;
  final bool personalDataRedacted;
  final bool rawImageStored;
  final int productsFound;
  final int productsMatched;
  final int pricesUpdated;
  final String shoppingTripId;
  final int reviewRequired;
  final String message;

  const ReceiptProcessingResult({
    required this.receiptId,
    required this.status,
    required this.personalDataRedacted,
    required this.rawImageStored,
    required this.productsFound,
    required this.productsMatched,
    required this.pricesUpdated,
    required this.shoppingTripId,
    required this.reviewRequired,
    required this.message,
  });

  bool get wasSuccessful => status == 'processed' || status == 'pending_review';

  bool get requiresReview => reviewRequired > 0;
}

class DuplicateReceiptException implements Exception {
  final List<ShoppingTrip> possibleDuplicates;

  const DuplicateReceiptException({required this.possibleDuplicates});

  ShoppingTrip get firstDuplicate => possibleDuplicates.first;

  @override
  String toString() {
    return 'DuplicateReceiptException: '
        '${possibleDuplicates.length} possible duplicate receipt(s) found.';
  }
}

class ReceiptProcessingException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const ReceiptProcessingException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    if (cause == null) {
      return 'ReceiptProcessingException: $message';
    }

    return 'ReceiptProcessingException: $message Cause: $cause';
  }
}

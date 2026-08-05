import '../models/receipt_item.dart';
import '../models/shopping_trip.dart';
import 'receipt_intelligence_service.dart';
import 'receipt_item_mapper.dart';

class ReceiptBuilderService {
  const ReceiptBuilderService._();

  static List<ReceiptItem> buildItemsFromIntelligence({
    required String receiptId,
    required ReceiptIntelligenceResult intelligenceResult,
  }) {
    _validateReceiptId(receiptId);

    return intelligenceResult.productMatches
        .map(
          (match) => ReceiptItemMapper.fromProductMatch(
            receiptId: receiptId,
            match: match,
          ),
        )
        .toList();
  }

  static List<ReceiptItem> buildItemsFromReviewedTrip({
    required String receiptId,
    required ShoppingTrip reviewedTrip,
  }) {
    _validateReceiptId(receiptId);

    return reviewedTrip.items
        .map(
          (item) => ReceiptItemMapper.fromShoppingTripItem(
            receiptId: receiptId,
            item: item,
          ),
        )
        .toList();
  }

  static void _validateReceiptId(String receiptId) {
    if (receiptId.trim().isEmpty) {
      throw const ReceiptBuilderException(
        'Receipt items cannot be built without a receipt ID.',
      );
    }
  }
}

class ReceiptBuilderException implements Exception {
  final String message;

  const ReceiptBuilderException(this.message);

  @override
  String toString() => 'ReceiptBuilderException: $message';
}
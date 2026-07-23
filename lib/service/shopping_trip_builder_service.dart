import '../models/shopping_trip.dart';
import 'receipt_intelligence_service.dart';

class ShoppingTripBuilderService {
  static ShoppingTrip buildFromReceiptIntelligence({
    required ReceiptIntelligenceResult intelligenceResult,
    required String storeId,
    required String storeName,
    required String city,
    required String province,
  }) {
    final parsedReceipt = intelligenceResult.parsedReceipt;

    final items = intelligenceResult.productMatches.map((match) {
      final matchedProduct = match.product;
      final quantity = match.receiptItem.quantity <= 0
          ? 1.0
          : match.receiptItem.quantity;

      final lineTotal = match.receiptItem.price;
      final unitPrice = lineTotal / quantity;

      return ShoppingTripItem(
        id: '',
        shoppingTripId: '',
        rawReceiptName: match.receiptItem.name,
        product: matchedProduct,
        barcode: matchedProduct?.barcode ?? '',
        quantity: quantity,
        unitPrice: unitPrice,
        lineTotal: lineTotal,
        confidenceScore: match.confidenceScore,
        requiresReview: !match.hasMatch || match.confidenceScore < 75,
      );
    }).toList();

    final tripStatus = items.any((item) => item.requiresReview)
        ? 'pending_review'
        : 'verified';

    return ShoppingTrip(
      id: '',
      storeId: storeId,
      storeName: storeName.isEmpty ? parsedReceipt.storeName : storeName,
      city: city,
      province: province,
      purchaseDate: parsedReceipt.purchaseDate ?? DateTime.now(),
      subtotal: parsedReceipt.subtotal,
      tax: parsedReceipt.tax,
      total: parsedReceipt.total,
      source: 'receipt',
      processingStatus: tripStatus,
      items: items,
    );
  }
}

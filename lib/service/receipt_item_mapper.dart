import '../models/receipt_item.dart';
import '../models/shopping_trip.dart';
import 'product_matcher_service.dart';

class ReceiptItemMapper {
  const ReceiptItemMapper._();

  static ReceiptItem fromProductMatch({
    required String receiptId,
    required ProductMatchResult match,
  }) {
    final quantity = match.receiptItem.quantity <= 0
        ? 1.0
        : match.receiptItem.quantity;

    final totalPrice = match.receiptItem.price;
    final unitPrice = totalPrice / quantity;
    final matchedProduct = match.product;

    return ReceiptItem(
      id: '',
      receiptId: receiptId,
            barcode: matchedProduct?.barcode.trim().isEmpty ?? true
          ? null
          : matchedProduct!.barcode,
      productName: match.receiptItem.name,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      taxAmount: 0,
      matchedProduct: match.hasMatch,
      confidenceScore: match.confidenceScore,
      createdAt: DateTime.now(),
    );
  }

  static ReceiptItem fromShoppingTripItem({
    required String receiptId,
    required ShoppingTripItem item,
  }) {
    final quantity = item.quantity <= 0 ? 1.0 : item.quantity;

    return ReceiptItem(
      id: '',
      receiptId: receiptId,
         barcode: item.barcode.trim().isEmpty ? null : item.barcode,
      productName: item.rawReceiptName,
      quantity: quantity,
      unitPrice: item.unitPrice,
      totalPrice: item.lineTotal,
      taxAmount: 0,
      matchedProduct: item.product != null,
      confidenceScore: item.confidenceScore,
      createdAt: DateTime.now(),
    );
  }
}
class ReceiptItem {
  final String id;
  final String receiptId;
  final String? barcode;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double taxAmount;
  final bool matchedProduct;
  final double confidenceScore;
  final DateTime? createdAt;

  const ReceiptItem({
    required this.id,
    required this.receiptId,
    this.barcode,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.totalPrice = 0,
    this.taxAmount = 0,
    this.matchedProduct = false,
    this.confidenceScore = 0,
    this.createdAt,
  });

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      id: map['id'] ?? '',
      receiptId: map['receipt_id'] ?? '',
      barcode: map['barcode'],
      productName: map['product_name'] ?? '',
      quantity: double.tryParse(map['quantity'].toString()) ?? 1,
      unitPrice: double.tryParse(map['unit_price'].toString()) ?? 0,
      totalPrice: double.tryParse(map['total_price'].toString()) ?? 0,
      taxAmount: double.tryParse(map['tax_amount'].toString()) ?? 0,
      matchedProduct: map['matched_product'] ?? false,
      confidenceScore:
          double.tryParse(map['confidence_score'].toString()) ?? 0,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receipt_id': receiptId,
      'barcode': barcode,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'tax_amount': taxAmount,
      'matched_product': matchedProduct,
      'confidence_score': confidenceScore,
    };
  }
}
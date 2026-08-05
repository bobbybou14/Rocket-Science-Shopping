import 'product.dart';

class ShoppingTrip {
  final String id;
  final String storeId;
  final String storeName;
  final String city;
  final String province;
  final DateTime purchaseDate;
  final double subtotal;
  final double tax;
  final double total;
  final String source;
  final String processingStatus;
  final DateTime? createdAt;
  final List<ShoppingTripItem> items;

  const ShoppingTrip({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.city,
    required this.province,
    required this.purchaseDate,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.source = 'receipt',
    this.processingStatus = 'pending_review',
    this.createdAt,
    this.items = const [],
  });

  factory ShoppingTrip.fromMap(
    Map<String, dynamic> map, {
    List<ShoppingTripItem> items = const [],
  }) {
    return ShoppingTrip(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      storeName: map['store_name']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      province: map['province']?.toString() ?? '',
      purchaseDate:
          DateTime.tryParse(map['purchase_date']?.toString() ?? '') ??
          DateTime.now(),
      subtotal: _toDouble(map['subtotal']),
      tax: _toDouble(map['tax']),
      total: _toDouble(map['total']),
      source: map['source']?.toString() ?? 'receipt',
      processingStatus:
          map['processing_status']?.toString() ?? 'pending_review',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_id': storeId.isEmpty ? null : storeId,
      'store_name': storeName,
      'city': city,
      'province': province,
      'purchase_date': purchaseDate.toIso8601String(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'source': source,
      'processing_status': processingStatus,
    };
  }

  ShoppingTrip copyWith({
    String? id,
    String? storeId,
    String? storeName,
    String? city,
    String? province,
    DateTime? purchaseDate,
    double? subtotal,
    double? tax,
    double? total,
    String? source,
    String? processingStatus,
    DateTime? createdAt,
    List<ShoppingTripItem>? items,
  }) {
    return ShoppingTrip(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      city: city ?? this.city,
      province: province ?? this.province,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      source: source ?? this.source,
      processingStatus: processingStatus ?? this.processingStatus,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ShoppingTripItem {
  final String id;
  final String shoppingTripId;
  final String rawReceiptName;
  final Product? product;
  final String barcode;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double confidenceScore;
  final bool requiresReview;
  final DateTime? createdAt;

  const ShoppingTripItem({
    required this.id,
    required this.shoppingTripId,
    required this.rawReceiptName,
    this.product,
    this.barcode = '',
    this.quantity = 1,
    required this.unitPrice,
    required this.lineTotal,
    this.confidenceScore = 0,
    this.requiresReview = true,
    this.createdAt,
  });
  ShoppingTripItem copyWith({
    String? id,
    String? shoppingTripId,
    String? rawReceiptName,
    Product? product,
    bool clearProduct = false,
    String? barcode,
    double? quantity,
    double? unitPrice,
    double? lineTotal,
    double? confidenceScore,
    bool? requiresReview,
    DateTime? createdAt,
  }) {
    final updatedProduct = clearProduct ? null : product ?? this.product;

    return ShoppingTripItem(
      id: id ?? this.id,
      shoppingTripId: shoppingTripId ?? this.shoppingTripId,
      rawReceiptName: rawReceiptName ?? this.rawReceiptName,
      product: updatedProduct,
      barcode: barcode ?? updatedProduct?.barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      requiresReview: requiresReview ?? this.requiresReview,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ShoppingTripItem.fromMap(
    Map<String, dynamic> map, {
    Product? product,
  }) {
    return ShoppingTripItem(
      id: map['id']?.toString() ?? '',
      shoppingTripId: map['shopping_trip_id']?.toString() ?? '',
      rawReceiptName: map['raw_receipt_name']?.toString() ?? '',
      product: product,
      barcode: map['barcode']?.toString() ?? '',
      quantity: ShoppingTrip._toDouble(map['quantity']),
      unitPrice: ShoppingTrip._toDouble(map['unit_price']),
      lineTotal: ShoppingTrip._toDouble(map['line_total']),
      confidenceScore: ShoppingTrip._toDouble(map['confidence_score']),
      requiresReview: map['requires_review'] == true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopping_trip_id': shoppingTripId.isEmpty ? null : shoppingTripId,
      'raw_receipt_name': rawReceiptName,
      'barcode': barcode.isEmpty ? null : barcode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
      'confidence_score': confidenceScore,
      'requires_review': requiresReview,
    };
  }
}

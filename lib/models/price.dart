class Price {
  final String id;
  final String barcode;
  final String? storeId;
  final String store;
  final String province;
  final String city;
  final double price;
  final String currency;

  // NEW
  final String source;
  final String? receiptId;
  final String notes;

  final DateTime? createdAt;

  const Price({
    required this.id,
    required this.barcode,
    this.storeId,
    this.store = '',
    this.province = '',
    this.city = '',
    required this.price,
    this.currency = 'CAD',

    this.source = 'manual',
    this.receiptId,
    this.notes = '',

    this.createdAt,
  });

  factory Price.fromMap(Map<String, dynamic> map) {
    return Price(
      id: map['id'] ?? '',
      barcode: map['barcode'] ?? '',
      storeId: map['store_id'],
      store: map['store'] ?? '',
      province: map['province'] ?? '',
      city: map['city'] ?? '',
      price: double.tryParse(map['price'].toString()) ?? 0.0,
      currency: map['currency'] ?? 'CAD',

      source: map['source'] ?? 'manual',
      receiptId: map['receipt_id'],
      notes: map['notes'] ?? '',

      createdAt: map['created_at'] == null
    ? null
    : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'store_id': storeId,
      'store': store,
      'province': province,
      'city': city,
      'price': price,
      'currency': currency,

      'source': source,
      'receipt_id': receiptId,
      'notes': notes,
    };
  }

  bool get isManual => source == 'manual';

  bool get isReceipt => source == 'receipt';

  bool get isFlyer => source == 'flyer';

  bool get isApi => source == 'api';
}
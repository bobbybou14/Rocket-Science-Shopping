class Receipt {
  final String id;
  final String? storeId;
  final String storeName;
  final String province;
  final String city;
  final DateTime? purchaseDate;
  final double subtotal;
  final double tax;
  final double total;
  final String source;
  final String processingStatus;
  final bool personalDataRedacted;
  final bool rawImageStored;
  final String notes;
  final DateTime? createdAt;

  const Receipt({
    required this.id,
    this.storeId,
    this.storeName = '',
    this.province = '',
    this.city = '',
    this.purchaseDate,
    this.subtotal = 0,
    this.tax = 0,
    this.total = 0,
    this.source = 'receipt',
    this.processingStatus = 'pending',
    this.personalDataRedacted = true,
    this.rawImageStored = false,
    this.notes = '',
    this.createdAt,
  });

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] ?? '',
      storeId: map['store_id'],
      storeName: map['store_name'] ?? '',
      province: map['province'] ?? '',
      city: map['city'] ?? '',
      purchaseDate: map['purchase_date'] == null
          ? null
          : DateTime.tryParse(map['purchase_date'].toString()),
      subtotal: double.tryParse(map['subtotal'].toString()) ?? 0,
      tax: double.tryParse(map['tax'].toString()) ?? 0,
      total: double.tryParse(map['total'].toString()) ?? 0,
      source: map['source'] ?? 'receipt',
      processingStatus: map['processing_status'] ?? 'pending',
      personalDataRedacted: map['personal_data_redacted'] ?? true,
      rawImageStored: map['raw_image_stored'] ?? false,
      notes: map['notes'] ?? '',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'province': province,
      'city': city,
      'purchase_date': purchaseDate?.toIso8601String(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'source': source,
      'processing_status': processingStatus,
      'personal_data_redacted': personalDataRedacted,
      'raw_image_stored': rawImageStored,
      'notes': notes,
    };
  }
}
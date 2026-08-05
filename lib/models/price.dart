import 'measurement_unit.dart';

class Price {
  final String id;
  final String barcode;
  final String? storeId;
  final String store;
  final String province;
  final String city;
  final double price;
  final String currency;

  final String source;
  final String? receiptId;
  final String notes;

  // Measurement
  final MeasurementUnit advertisedUnit;
  final double measurementQuantity;
  final MeasurementUnit normalizedUnit;
  final double? normalizedUnitPrice;

  // Sale information
  final bool isSale;
  final double? regularPrice;
  final DateTime? saleStartDate;
  final DateTime? saleEndDate;
  final String? promotionType;

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
    this.advertisedUnit = MeasurementUnit.each,
    this.measurementQuantity = 1,
    this.normalizedUnit = MeasurementUnit.each,
    this.normalizedUnitPrice,
    this.isSale = false,
    this.regularPrice,
    this.saleStartDate,
    this.saleEndDate,
    this.promotionType,
    this.createdAt,
  });

  factory Price.fromMap(Map<String, dynamic> map) {
    return Price(
      id: map['id']?.toString() ?? '',
      barcode: map['barcode']?.toString() ?? '',
      storeId: map['store_id']?.toString(),
      store: map['store']?.toString() ?? '',
      province: map['province']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      price: _toDouble(map['price']) ?? 0,
      currency: map['currency']?.toString() ?? 'CAD',
      source: map['source']?.toString() ?? 'manual',
      receiptId: map['receipt_id']?.toString(),
      notes: map['notes']?.toString() ?? '',
      advertisedUnit: MeasurementUnit.fromDatabase(map['advertised_unit']),
      measurementQuantity: _toDouble(map['measurement_quantity']) ?? 1,
      normalizedUnit: MeasurementUnit.fromDatabase(map['normalized_unit']),
      normalizedUnitPrice: _toDouble(map['normalized_unit_price']),
      isSale: map['is_sale'] == true,
      regularPrice: _toDouble(map['regular_price']),
      saleStartDate: _toDateTime(map['sale_start_date']),
      saleEndDate: _toDateTime(map['sale_end_date']),
      promotionType: map['promotion_type']?.toString(),
      createdAt: _toDateTime(map['created_at']),
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
      'advertised_unit': advertisedUnit.databaseValue,
      'measurement_quantity': measurementQuantity,
      'normalized_unit': normalizedUnit.databaseValue,
      'normalized_unit_price': normalizedUnitPrice,
      'is_sale': isSale,
      'regular_price': regularPrice,
      'sale_start_date': saleStartDate?.toIso8601String(),
      'sale_end_date': saleEndDate?.toIso8601String(),
      'promotion_type': promotionType,
    };
  }

  bool get isManual => source == 'manual';

  bool get isReceipt => source == 'receipt';

  bool get isFlyer => source == 'flyer';

  bool get isApi => source == 'api';

  bool get hasNormalizedUnitPrice =>
      normalizedUnitPrice != null && normalizedUnitPrice! > 0;

  bool get hasRegularPrice => regularPrice != null && regularPrice! > 0;

  bool get hasActiveSale {
    if (!isSale) {
      return false;
    }

    final now = DateTime.now();

    if (saleStartDate != null && now.isBefore(saleStartDate!)) {
      return false;
    }

    if (saleEndDate != null && now.isAfter(saleEndDate!)) {
      return false;
    }

    return true;
  }

  double get savingsAmount {
    if (!isSale || regularPrice == null || regularPrice! <= price) {
      return 0;
    }

    return regularPrice! - price;
  }

  double get savingsPercentage {
    if (regularPrice == null || regularPrice! <= 0) {
      return 0;
    }

    return (savingsAmount / regularPrice!) * 100;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}

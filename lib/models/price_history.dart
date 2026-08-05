import 'measurement_unit.dart';

class PriceHistoryEntry {
  final String id;
  final String barcode;
  final String storeId;
  final String store;
  final String province;
  final String city;
  final double price;
  final String currency;
  final String source;
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

  final DateTime createdAt;

  const PriceHistoryEntry({
    required this.id,
    required this.barcode,
    required this.storeId,
    required this.store,
    required this.province,
    required this.city,
    required this.price,
    required this.currency,
    required this.source,
    required this.notes,
    required this.createdAt,
    this.advertisedUnit = MeasurementUnit.each,
    this.measurementQuantity = 1,
    this.normalizedUnit = MeasurementUnit.each,
    this.normalizedUnitPrice,
    this.isSale = false,
    this.regularPrice,
    this.saleStartDate,
    this.saleEndDate,
    this.promotionType,
  });

  factory PriceHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PriceHistoryEntry(
      id: map['id']?.toString() ?? '',
      barcode: map['barcode']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      store: map['store']?.toString() ?? '',
      province: map['province']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      price: _toDouble(map['price']),
      currency: map['currency']?.toString() ?? 'CAD',
      source: map['source']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      advertisedUnit: MeasurementUnit.fromDatabase(map['advertised_unit']),
      measurementQuantity: _toDouble(map['measurement_quantity'], 1),
      normalizedUnit: MeasurementUnit.fromDatabase(map['normalized_unit']),
      normalizedUnitPrice: _toNullableDouble(map['normalized_unit_price']),
      isSale: map['is_sale'] == true,
      regularPrice: _toNullableDouble(map['regular_price']),
      saleStartDate: _toDateTime(map['sale_start_date']),
      saleEndDate: _toDateTime(map['sale_end_date']),
      promotionType: map['promotion_type']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

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
    if (!hasRegularPrice || regularPrice! <= price) {
      return 0;
    }

    return regularPrice! - price;
  }

  double get savingsPercentage {
    if (!hasRegularPrice || regularPrice! <= 0) {
      return 0;
    }

    return (savingsAmount / regularPrice!) * 100;
  }

  static double _toDouble(dynamic value, [double fallback = 0]) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _toNullableDouble(dynamic value) {
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

class PriceHistorySummary {
  final List<PriceHistoryEntry> entries;
  final double currentPrice;
  final double lowestPrice;
  final double highestPrice;
  final double averagePrice;
  final double priceChange;
  final double percentageChange;
  final String trend;
  final String bestStore;
  final String mostRecentStore;
  final DateTime? lastUpdated;

  const PriceHistorySummary({
    required this.entries,
    required this.currentPrice,
    required this.lowestPrice,
    required this.highestPrice,
    required this.averagePrice,
    required this.priceChange,
    required this.percentageChange,
    required this.trend,
    required this.bestStore,
    required this.mostRecentStore,
    required this.lastUpdated,
  });

  const PriceHistorySummary.empty()
    : entries = const [],
      currentPrice = 0,
      lowestPrice = 0,
      highestPrice = 0,
      averagePrice = 0,
      priceChange = 0,
      percentageChange = 0,
      trend = 'No data',
      bestStore = 'Not available',
      mostRecentStore = 'Not available',
      lastUpdated = null;

  bool get hasData => entries.isNotEmpty;

  int get priceCount => entries.length;
}

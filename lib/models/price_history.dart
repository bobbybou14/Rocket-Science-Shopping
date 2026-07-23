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
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
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

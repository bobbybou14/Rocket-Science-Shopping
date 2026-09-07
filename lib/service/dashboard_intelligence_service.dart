import 'package:supabase_flutter/supabase_flutter.dart';

import 'favorites_service.dart';

class DashboardPriceAlert {
  final String barcode;
  final String productName;
  final String storeName;
  final double previousPrice;
  final double currentPrice;
  final double priceChange;
  final double percentageChange;
  final DateTime observedAt;

  const DashboardPriceAlert({
    required this.barcode,
    required this.productName,
    required this.storeName,
    required this.previousPrice,
    required this.currentPrice,
    required this.priceChange,
    required this.percentageChange,
    required this.observedAt,
  });

  bool get isPriceDrop => priceChange < 0;
}

class DashboardBestStore {
  final String storeName;
  final int tripCount;
  final double totalSpent;
  final double averageTripCost;

  const DashboardBestStore({
    required this.storeName,
    required this.tripCount,
    required this.totalSpent,
    required this.averageTripCost,
  });

  const DashboardBestStore.empty()
    : storeName = 'No Store Data',
      tripCount = 0,
      totalSpent = 0,
      averageTripCost = 0;

  bool get hasData => tripCount > 0;
}

class DashboardIntelligence {
  final DashboardBestStore bestStore;
  final List<DashboardPriceAlert> priceAlerts;

  const DashboardIntelligence({
    required this.bestStore,
    required this.priceAlerts,
  });

  const DashboardIntelligence.empty()
    : bestStore = const DashboardBestStore.empty(),
      priceAlerts = const [];
}

class DashboardIntelligenceService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<DashboardIntelligence> loadDashboardIntelligence() async {
    final results = await Future.wait([_loadBestStore(), _loadPriceAlerts()]);

    return DashboardIntelligence(
      bestStore: results[0] as DashboardBestStore,
      priceAlerts: results[1] as List<DashboardPriceAlert>,
    );
  }

  static Future<DashboardBestStore> _loadBestStore() async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      return const DashboardBestStore.empty();
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final response = await _supabase
        .from('shopping_trips')
        .select('store_name, total, purchase_date')
        .eq('user_id', userId)
        .gte('purchase_date', monthStart.toIso8601String());

    final rows = List<Map<String, dynamic>>.from(response);

    if (rows.isEmpty) {
      return const DashboardBestStore.empty();
    }

    final storeTotals = <String, double>{};
    final storeCounts = <String, int>{};
    final displayNames = <String, String>{};

    for (final row in rows) {
      final rawStoreName = row['store_name']?.toString().trim() ?? '';

      final storeName = rawStoreName.isEmpty ? 'Unknown Store' : rawStoreName;

      final key = storeName.toLowerCase();
      final total = _toDouble(row['total']);

      storeTotals[key] = (storeTotals[key] ?? 0) + total;
      storeCounts[key] = (storeCounts[key] ?? 0) + 1;
      displayNames[key] = storeName;
    }

    String? bestStoreKey;
    int highestTripCount = 0;
    double lowestAverageTripCost = double.infinity;

    for (final key in storeCounts.keys) {
      final tripCount = storeCounts[key] ?? 0;
      final totalSpent = storeTotals[key] ?? 0;

      final averageTripCost = tripCount == 0
          ? double.infinity
          : totalSpent / tripCount;

      final hasMoreTrips = tripCount > highestTripCount;

      final hasSameTripsButLowerAverage =
          tripCount == highestTripCount &&
          averageTripCost < lowestAverageTripCost;

      if (hasMoreTrips || hasSameTripsButLowerAverage) {
        bestStoreKey = key;
        highestTripCount = tripCount;
        lowestAverageTripCost = averageTripCost;
      }
    }

    if (bestStoreKey == null) {
      return const DashboardBestStore.empty();
    }

    final tripCount = storeCounts[bestStoreKey] ?? 0;
    final totalSpent = storeTotals[bestStoreKey] ?? 0;
    final double averageTripCost = tripCount == 0
        ? 0.0
        : totalSpent / tripCount;

    return DashboardBestStore(
      storeName: displayNames[bestStoreKey] ?? 'Unknown Store',
      tripCount: tripCount,
      totalSpent: totalSpent,
      averageTripCost: averageTripCost,
    );
  }

  static Future<List<DashboardPriceAlert>> _loadPriceAlerts() async {
    final favorites = await FavoritesService.getFavorites();
    final favoriteBarcodes = favorites
        .map((favorite) => favorite.barcode.trim())
        .where((barcode) => barcode.isNotEmpty)
        .toSet()
        .toList();

    if (favoriteBarcodes.isEmpty) {
      return [];
    }

    final response = await _supabase
        .from('prices')
        .select('''
          barcode,
          store,
          price,
          created_at,
          products (
            name,
            brand,
            size
          )
                ''')
        .inFilter('barcode', favoriteBarcodes)
        .order('created_at', ascending: false)
        .limit(250);

    final rows = List<Map<String, dynamic>>.from(response);

    final groupedRows = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final barcode = row['barcode']?.toString().trim() ?? '';

      if (barcode.isEmpty) {
        continue;
      }

      groupedRows.putIfAbsent(barcode, () => []);
      groupedRows[barcode]!.add(row);
    }

    final alerts = <DashboardPriceAlert>[];

    for (final entry in groupedRows.entries) {
      final productRows = entry.value;

      if (productRows.length < 2) {
        continue;
      }

      productRows.sort((a, b) {
        final aDate = _toDateTime(a['created_at']);
        final bDate = _toDateTime(b['created_at']);

        return bDate.compareTo(aDate);
      });

      final latestRow = productRows[0];
      final previousRow = productRows[1];

      final currentPrice = _toDouble(latestRow['price']);
      final previousPrice = _toDouble(previousRow['price']);

      if (currentPrice <= 0 || previousPrice <= 0) {
        continue;
      }

      final priceChange = currentPrice - previousPrice;
      final percentageChange = (priceChange / previousPrice) * 100;

      if (percentageChange.abs() < 2) {
        continue;
      }

      alerts.add(
        DashboardPriceAlert(
          barcode: entry.key,
          productName: _productDisplayName(latestRow),
          storeName: latestRow['store']?.toString().trim().isEmpty ?? true
              ? 'Unknown Store'
              : latestRow['store'].toString().trim(),
          previousPrice: previousPrice,
          currentPrice: currentPrice,
          priceChange: priceChange,
          percentageChange: percentageChange,
          observedAt: _toDateTime(latestRow['created_at']),
        ),
      );
    }

    alerts.sort(
      (a, b) => b.percentageChange.abs().compareTo(a.percentageChange.abs()),
    );

    return alerts.take(3).toList();
  }

  static String _productDisplayName(Map<String, dynamic> row) {
    final productData = row['products'];

    if (productData is Map) {
      final productMap = Map<String, dynamic>.from(productData);

      final parts = [
        productMap['brand']?.toString() ?? '',
        productMap['name']?.toString() ?? '',
        productMap['size']?.toString() ?? '',
      ].where((value) => value.trim().isNotEmpty).toList();

      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }

    return row['barcode']?.toString() ?? 'Unknown Product';
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _toDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

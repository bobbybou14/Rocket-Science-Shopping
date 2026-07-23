import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/price_history.dart';

export '../models/price_history.dart';

class PriceHistoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<PriceHistorySummary> getPriceHistory(String barcode) async {
    final cleanedBarcode = barcode.trim();

    if (cleanedBarcode.isEmpty) {
      return const PriceHistorySummary.empty();
    }

    final response = await _supabase
        .from('prices')
        .select()
        .eq('barcode', cleanedBarcode)
        .order('created_at', ascending: true);

    final entries = List<Map<String, dynamic>>.from(
      response,
    ).map(PriceHistoryEntry.fromMap).where((entry) => entry.price > 0).toList();

    if (entries.isEmpty) {
      return const PriceHistorySummary.empty();
    }

    final prices = entries.map((entry) => entry.price).toList();

    final currentEntry = entries.last;
    final currentPrice = currentEntry.price;

    final lowestEntry = entries.reduce((current, next) {
      return next.price < current.price ? next : current;
    });

    final highestEntry = entries.reduce((current, next) {
      return next.price > current.price ? next : current;
    });

    final totalPrice = prices.fold<double>(0, (total, price) => total + price);

    final averagePrice = totalPrice / prices.length;

    final priceChange = _calculatePriceChange(entries);
    final percentageChange = _calculatePercentageChange(entries);
    final trend = _calculateTrend(priceChange);

    return PriceHistorySummary(
      entries: entries,
      currentPrice: currentPrice,
      lowestPrice: lowestEntry.price,
      highestPrice: highestEntry.price,
      averagePrice: averagePrice,
      priceChange: priceChange,
      percentageChange: percentageChange,
      trend: trend,
      bestStore: _displayStoreName(lowestEntry.store),
      mostRecentStore: _displayStoreName(currentEntry.store),
      lastUpdated: currentEntry.createdAt,
    );
  }

  static double _calculatePriceChange(List<PriceHistoryEntry> entries) {
    if (entries.length < 2) {
      return 0;
    }

    final previousPrice = entries[entries.length - 2].price;
    final currentPrice = entries.last.price;

    return currentPrice - previousPrice;
  }

  static double _calculatePercentageChange(List<PriceHistoryEntry> entries) {
    if (entries.length < 2) {
      return 0;
    }

    final previousPrice = entries[entries.length - 2].price;
    final currentPrice = entries.last.price;

    if (previousPrice <= 0) {
      return 0;
    }

    return ((currentPrice - previousPrice) / previousPrice) * 100;
  }

  static String _calculateTrend(double priceChange) {
    if (priceChange.abs() < 0.01) {
      return 'Stable';
    }

    if (priceChange > 0) {
      return 'Rising';
    }

    return 'Falling';
  }

  static String _displayStoreName(String storeName) {
    final cleanedName = storeName.trim();

    if (cleanedName.isEmpty) {
      return 'Unknown Store';
    }

    return cleanedName;
  }
}

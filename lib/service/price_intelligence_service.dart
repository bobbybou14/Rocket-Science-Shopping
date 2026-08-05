import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/price_intelligence.dart';

class PriceIntelligenceService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const int _minimumObservations = 3;
  static const int _mediumConfidenceObservations = 6;
  static const int _highConfidenceObservations = 12;

  static const double _priceEqualityTolerance = 0.005;
  static const double _stableTrendPercent = 2.0;

  static const double _excellentBuyBelowAveragePercent = -15.0;
  static const double _goodBuyBelowAveragePercent = -5.0;
  static const double _overpricedAboveAveragePercent = 10.0;

  /// Loads and analyzes the complete valid shelf-price history for a product.
  ///
  /// Returns `null` when the barcode is blank or no valid price observations
  /// exist.
  static Future<PriceIntelligence?> analyzeProduct({
    required String barcode,
  }) async {
    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) {
      return null;
    }

    final observations = await loadPriceObservations(
      barcode: normalizedBarcode,
    );

    return analyzeObservations(observations);
  }

  /// Loads valid price observations for one barcode.
  ///
  /// Records are returned from oldest to newest so they can be used directly
  /// for trend analysis and charting.
  static Future<List<PriceObservation>> loadPriceObservations({
    required String barcode,
  }) async {
    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) {
      return const [];
    }

    final response = await _supabase
        .from('prices')
        .select(
          'price, '
          'store_id, '
          'created_at',
        )
        .eq('barcode', normalizedBarcode)
        .order('created_at', ascending: true);

    final rows = List<Map<String, dynamic>>.from(response);
    final observations = <PriceObservation>[];

    for (final row in rows) {
      final observation = PriceObservation.fromMap(row);

      if (observation != null) {
        observations.add(observation);
      }
    }

    observations.sort(
      (first, second) => first.recordedAt.compareTo(second.recordedAt),
    );

    return observations;
  }

  /// Calculates intelligence from already-loaded observations.
  ///
  /// Keeping this separate from Supabase access allows the algorithm to be
  /// tested without a database and reused with cached or imported data.
  static PriceIntelligence? analyzeObservations(
    List<PriceObservation> observations,
  ) {
    final validObservations =
        observations.where((observation) {
          return observation.price.isFinite && observation.price > 0;
        }).toList()..sort(
          (first, second) => first.recordedAt.compareTo(second.recordedAt),
        );

    if (validObservations.isEmpty) {
      return null;
    }

    final prices = validObservations
        .map((observation) => observation.price)
        .toList();

    final currentObservation = validObservations.last;
    final currentPrice = currentObservation.price;

    final averagePrice = _calculateAverage(prices);
    final medianPrice = _calculateMedian(prices);

    final lowestPrice = prices.reduce(
      (current, next) => next < current ? next : current,
    );

    final highestPrice = prices.reduce(
      (current, next) => next > current ? next : current,
    );

    final lowestObservation = _findMostRecentMatchingObservation(
      observations: validObservations,
      targetPrice: lowestPrice,
    );

    final highestObservation = _findMostRecentMatchingObservation(
      observations: validObservations,
      targetPrice: highestPrice,
    );

    final currentVsAveragePercent = _percentageDifference(
      current: currentPrice,
      reference: averagePrice,
    );

    final currentVsLowestPercent = _percentageDifference(
      current: currentPrice,
      reference: lowestPrice,
    );

    final savingsVsAverage = averagePrice - currentPrice;
    final distanceFromLowest = currentPrice - lowestPrice;

    final isHistoricalLow = _approximatelyEqual(currentPrice, lowestPrice);

    final isHistoricalHigh = _approximatelyEqual(currentPrice, highestPrice);

    final trend = _determineTrend(validObservations);
    final storeCount = _countStores(validObservations);

    final confidence = _determineConfidence(
      observations: validObservations,
      storeCount: storeCount,
    );

    final recommendation = _determineRecommendation(
      observations: validObservations.length,
      currentVsAveragePercent: currentVsAveragePercent,
      currentVsLowestPercent: currentVsLowestPercent,
      isHistoricalLow: isHistoricalLow,
      trend: trend,
    );

    return PriceIntelligence(
      currentPrice: currentPrice,
      averagePrice: averagePrice,
      lowestPrice: lowestPrice,
      highestPrice: highestPrice,
      medianPrice: medianPrice,
      currentVsAveragePercent: currentVsAveragePercent,
      currentVsLowestPercent: currentVsLowestPercent,
      savingsVsAverage: savingsVsAverage,
      distanceFromLowest: distanceFromLowest,
      observations: validObservations.length,
      storeCount: storeCount,
      firstSeen: validObservations.first.recordedAt,
      lastSeen: currentObservation.recordedAt,
      lowestSeen: lowestObservation?.recordedAt,
      highestSeen: highestObservation?.recordedAt,
      trend: trend,
      recommendation: recommendation,
      confidence: confidence,
      isHistoricalLow: isHistoricalLow,
      isHistoricalHigh: isHistoricalHigh,
    );
  }

  /// Analyzes several products with one batched database request.
  ///
  /// The returned map is keyed by barcode. Barcodes without valid history are
  /// omitted.
  static Future<Map<String, PriceIntelligence>> analyzeProducts({
    required Iterable<String> barcodes,
  }) async {
    final normalizedBarcodes = barcodes
        .map((barcode) => barcode.trim())
        .where((barcode) => barcode.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedBarcodes.isEmpty) {
      return {};
    }

    final response = await _supabase
        .from('prices')
        .select(
          'barcode, '
          'price, '
          'store_id, '
          'created_at',
        )
        .inFilter('barcode', normalizedBarcodes)
        .order('created_at', ascending: true);

    final rows = List<Map<String, dynamic>>.from(response);
    final observationsByBarcode = <String, List<PriceObservation>>{};

    for (final row in rows) {
      final barcode = _stringValue(row['barcode']);
      final observation = PriceObservation.fromMap(row);

      if (barcode.isEmpty || observation == null) {
        continue;
      }

      observationsByBarcode
          .putIfAbsent(barcode, () => <PriceObservation>[])
          .add(observation);
    }

    final results = <String, PriceIntelligence>{};

    for (final entry in observationsByBarcode.entries) {
      final intelligence = analyzeObservations(entry.value);

      if (intelligence != null) {
        results[entry.key] = intelligence;
      }
    }

    return results;
  }

  static double _calculateAverage(List<double> prices) {
    if (prices.isEmpty) {
      return 0;
    }

    final total = prices.fold<double>(0, (sum, price) => sum + price);

    return total / prices.length;
  }

  static double _calculateMedian(List<double> prices) {
    if (prices.isEmpty) {
      return 0;
    }

    final sortedPrices = List<double>.from(prices)..sort();
    final middleIndex = sortedPrices.length ~/ 2;

    if (sortedPrices.length.isOdd) {
      return sortedPrices[middleIndex];
    }

    return (sortedPrices[middleIndex - 1] + sortedPrices[middleIndex]) / 2;
  }

  static double _percentageDifference({
    required double current,
    required double reference,
  }) {
    if (!reference.isFinite || reference <= 0) {
      return 0;
    }

    return ((current - reference) / reference) * 100;
  }

  static PriceObservation? _findMostRecentMatchingObservation({
    required List<PriceObservation> observations,
    required double targetPrice,
  }) {
    for (final observation in observations.reversed) {
      if (_approximatelyEqual(observation.price, targetPrice)) {
        return observation;
      }
    }

    return null;
  }

  /// Compares recent prices with the preceding price window.
  ///
  /// For larger histories, the newest third is compared with the previous
  /// third. For shorter histories, the most recent price is compared with the
  /// average of the preceding observations.
  static PriceTrend _determineTrend(List<PriceObservation> observations) {
    if (observations.length < _minimumObservations) {
      return PriceTrend.unknown;
    }

    final prices = observations
        .map((observation) => observation.price)
        .toList();

    double earlierAverage;
    double recentAverage;

    if (prices.length >= 6) {
      final windowSize = prices.length ~/ 3;
      final recentStart = prices.length - windowSize;
      final earlierStart = recentStart - windowSize;

      earlierAverage = _calculateAverage(
        prices.sublist(earlierStart, recentStart),
      );

      recentAverage = _calculateAverage(prices.sublist(recentStart));
    } else {
      earlierAverage = _calculateAverage(prices.sublist(0, prices.length - 1));

      recentAverage = prices.last;
    }

    final changePercent = _percentageDifference(
      current: recentAverage,
      reference: earlierAverage,
    );

    if (changePercent > _stableTrendPercent) {
      return PriceTrend.rising;
    }

    if (changePercent < -_stableTrendPercent) {
      return PriceTrend.falling;
    }

    return PriceTrend.stable;
  }

  static int _countStores(List<PriceObservation> observations) {
    return observations
        .map((observation) => observation.storeId)
        .where((storeId) => storeId != null && storeId.isNotEmpty)
        .toSet()
        .length;
  }

  static IntelligenceConfidence _determineConfidence({
    required List<PriceObservation> observations,
    required int storeCount,
  }) {
    final observationCount = observations.length;

    if (observationCount < _minimumObservations) {
      return IntelligenceConfidence.low;
    }

    final historySpan = observations.last.recordedAt.difference(
      observations.first.recordedAt,
    );

    final spansAtLeastThirtyDays = historySpan.inDays >= 30;
    final spansAtLeastNinetyDays = historySpan.inDays >= 90;

    if (observationCount >= _highConfidenceObservations &&
        spansAtLeastNinetyDays &&
        storeCount >= 2) {
      return IntelligenceConfidence.high;
    }

    if (observationCount >= _mediumConfidenceObservations &&
        spansAtLeastThirtyDays) {
      return IntelligenceConfidence.medium;
    }

    return IntelligenceConfidence.low;
  }

  static BuyRecommendation _determineRecommendation({
    required int observations,
    required double currentVsAveragePercent,
    required double currentVsLowestPercent,
    required bool isHistoricalLow,
    required PriceTrend trend,
  }) {
    if (observations < _minimumObservations) {
      return BuyRecommendation.insufficientData;
    }

    if (isHistoricalLow ||
        currentVsAveragePercent <= _excellentBuyBelowAveragePercent ||
        currentVsLowestPercent <= 2.0 &&
            currentVsAveragePercent < _goodBuyBelowAveragePercent) {
      return BuyRecommendation.excellentBuy;
    }

    if (currentVsAveragePercent <= _goodBuyBelowAveragePercent) {
      return BuyRecommendation.goodBuy;
    }

    if (currentVsAveragePercent >= _overpricedAboveAveragePercent) {
      return BuyRecommendation.wait;
    }

    if (trend == PriceTrend.rising && currentVsAveragePercent > 5.0) {
      return BuyRecommendation.wait;
    }

    return BuyRecommendation.fairPrice;
  }

  static bool _approximatelyEqual(double first, double second) {
    return (first - second).abs() <= _priceEqualityTolerance;
  }

  static String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}

/// One validated historical shelf-price record used by the intelligence
/// engine.
class PriceObservation {
  final double price;
  final String? storeId;
  final DateTime recordedAt;

  const PriceObservation({
    required this.price,
    required this.storeId,
    required this.recordedAt,
  });

  static PriceObservation? fromMap(Map<String, dynamic> map) {
    final price = _parsePositiveDouble(map['price']);
    final recordedAt = _parseDateTime(map['created_at']);

    if (price == null || recordedAt == null) {
      return null;
    }

    final parsedStoreId = map['store_id']?.toString().trim();

    return PriceObservation(
      price: price,
      storeId: parsedStoreId == null || parsedStoreId.isEmpty
          ? null
          : parsedStoreId,
      recordedAt: recordedAt,
    );
  }

  static double? _parsePositiveDouble(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}

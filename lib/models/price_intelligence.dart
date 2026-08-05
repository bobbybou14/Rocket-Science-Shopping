enum PriceTrend { rising, falling, stable, unknown }

enum BuyRecommendation {
  excellentBuy,
  goodBuy,
  fairPrice,
  wait,
  insufficientData,
}

enum IntelligenceConfidence { low, medium, high }

class PriceIntelligence {
  /// Most recently recorded shelf price.
  final double currentPrice;

  /// Arithmetic mean of the valid historical observations.
  final double averagePrice;

  /// Lowest valid price recorded during the analyzed period.
  final double lowestPrice;

  /// Highest valid price recorded during the analyzed period.
  final double highestPrice;

  /// Median of the valid historical observations.
  ///
  /// The median is less affected by unusually high or low records than the
  /// arithmetic average.
  final double medianPrice;

  /// Percentage difference between the current and average prices.
  ///
  /// A negative value means the current price is below average.
  /// A positive value means the current price is above average.
  final double currentVsAveragePercent;

  /// Percentage difference between the current and historical-low prices.
  ///
  /// Zero means the current price is at the historical low.
  final double currentVsLowestPercent;

  /// Absolute amount saved compared with the historical average.
  ///
  /// This is positive when the current price is below average and negative
  /// when it is above average.
  final double savingsVsAverage;

  /// Absolute distance between the current price and historical low.
  final double distanceFromLowest;

  /// Number of valid price observations used in the analysis.
  final int observations;

  /// Number of different stores represented in the analysis.
  final int storeCount;

  /// Earliest observation included in the analysis.
  final DateTime? firstSeen;

  /// Most recent observation included in the analysis.
  final DateTime? lastSeen;

  /// Date when the lowest price was most recently observed.
  final DateTime? lowestSeen;

  /// Date when the highest price was most recently observed.
  final DateTime? highestSeen;

  /// Direction of recent prices.
  final PriceTrend trend;

  /// User-facing purchase recommendation.
  final BuyRecommendation recommendation;

  /// Confidence in the calculated recommendation.
  final IntelligenceConfidence confidence;

  /// True when the current price matches the lowest recorded price within the
  /// service's comparison tolerance.
  final bool isHistoricalLow;

  /// True when the current price matches the highest recorded price within the
  /// service's comparison tolerance.
  final bool isHistoricalHigh;

  const PriceIntelligence({
    required this.currentPrice,
    required this.averagePrice,
    required this.lowestPrice,
    required this.highestPrice,
    required this.medianPrice,
    required this.currentVsAveragePercent,
    required this.currentVsLowestPercent,
    required this.savingsVsAverage,
    required this.distanceFromLowest,
    required this.observations,
    required this.storeCount,
    required this.firstSeen,
    required this.lastSeen,
    required this.lowestSeen,
    required this.highestSeen,
    required this.trend,
    required this.recommendation,
    required this.confidence,
    required this.isHistoricalLow,
    required this.isHistoricalHigh,
  });

  bool get hasEnoughData => observations >= 3;

  bool get isBelowAverage => currentPrice < averagePrice;

  bool get isAboveAverage => currentPrice > averagePrice;

  bool get isGoodBuy =>
      recommendation == BuyRecommendation.goodBuy ||
      recommendation == BuyRecommendation.excellentBuy;

  bool get isExcellentBuy => recommendation == BuyRecommendation.excellentBuy;

  bool get isOverpriced => recommendation == BuyRecommendation.wait;

  bool get hasHighConfidence => confidence == IntelligenceConfidence.high;

  String get recommendationTitle {
    switch (recommendation) {
      case BuyRecommendation.excellentBuy:
        return 'Excellent Buy';
      case BuyRecommendation.goodBuy:
        return 'Good Buy';
      case BuyRecommendation.fairPrice:
        return 'Fair Price';
      case BuyRecommendation.wait:
        return 'Consider Waiting';
      case BuyRecommendation.insufficientData:
        return 'More Price Data Needed';
    }
  }

  String get recommendationMessage {
    switch (recommendation) {
      case BuyRecommendation.excellentBuy:
        if (isHistoricalLow) {
          return 'This is the lowest recorded price.';
        }

        return 'The current price is significantly below its historical '
            'average.';

      case BuyRecommendation.goodBuy:
        return 'The current price is below its historical average.';

      case BuyRecommendation.fairPrice:
        return 'The current price is close to its historical average.';

      case BuyRecommendation.wait:
        return 'The current price is above its historical average. Waiting '
            'for a better price may save money.';

      case BuyRecommendation.insufficientData:
        return 'More valid price observations are needed before a reliable '
            'recommendation can be made.';
    }
  }

  String get trendLabel {
    switch (trend) {
      case PriceTrend.rising:
        return 'Rising';
      case PriceTrend.falling:
        return 'Falling';
      case PriceTrend.stable:
        return 'Stable';
      case PriceTrend.unknown:
        return 'Unknown';
    }
  }

  String get confidenceLabel {
    switch (confidence) {
      case IntelligenceConfidence.low:
        return 'Low';
      case IntelligenceConfidence.medium:
        return 'Medium';
      case IntelligenceConfidence.high:
        return 'High';
    }
  }

  PriceIntelligence copyWith({
    double? currentPrice,
    double? averagePrice,
    double? lowestPrice,
    double? highestPrice,
    double? medianPrice,
    double? currentVsAveragePercent,
    double? currentVsLowestPercent,
    double? savingsVsAverage,
    double? distanceFromLowest,
    int? observations,
    int? storeCount,
    DateTime? firstSeen,
    DateTime? lastSeen,
    DateTime? lowestSeen,
    DateTime? highestSeen,
    PriceTrend? trend,
    BuyRecommendation? recommendation,
    IntelligenceConfidence? confidence,
    bool? isHistoricalLow,
    bool? isHistoricalHigh,
  }) {
    return PriceIntelligence(
      currentPrice: currentPrice ?? this.currentPrice,
      averagePrice: averagePrice ?? this.averagePrice,
      lowestPrice: lowestPrice ?? this.lowestPrice,
      highestPrice: highestPrice ?? this.highestPrice,
      medianPrice: medianPrice ?? this.medianPrice,
      currentVsAveragePercent:
          currentVsAveragePercent ?? this.currentVsAveragePercent,
      currentVsLowestPercent:
          currentVsLowestPercent ?? this.currentVsLowestPercent,
      savingsVsAverage: savingsVsAverage ?? this.savingsVsAverage,
      distanceFromLowest: distanceFromLowest ?? this.distanceFromLowest,
      observations: observations ?? this.observations,
      storeCount: storeCount ?? this.storeCount,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      lowestSeen: lowestSeen ?? this.lowestSeen,
      highestSeen: highestSeen ?? this.highestSeen,
      trend: trend ?? this.trend,
      recommendation: recommendation ?? this.recommendation,
      confidence: confidence ?? this.confidence,
      isHistoricalLow: isHistoricalLow ?? this.isHistoricalLow,
      isHistoricalHigh: isHistoricalHigh ?? this.isHistoricalHigh,
    );
  }
}

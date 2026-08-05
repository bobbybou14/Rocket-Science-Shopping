import '../models/price_intelligence.dart';
import '../models/product.dart';
import 'favorites_service.dart';
import 'price_history_service.dart';
import 'price_intelligence_service.dart';

class WatchlistInsight {
  final FavoriteProduct favorite;
  final Product product;
  final PriceHistorySummary summary;
  final PriceIntelligence? intelligence;

  final String headline;
  final String message;
  final WatchlistInsightType type;

  final int intelligenceScore;
  final double potentialSavings;

  const WatchlistInsight({
    required this.favorite,
    required this.product,
    required this.summary,
    required this.intelligence,
    required this.headline,
    required this.message,
    required this.type,
    required this.intelligenceScore,
    required this.potentialSavings,
  });

  bool get hasPriceData => summary.hasData;

  bool get hasIntelligence => intelligence != null;

  BuyRecommendation get recommendation {
    return intelligence?.recommendation ?? BuyRecommendation.insufficientData;
  }

  PriceTrend get priceTrend {
    return intelligence?.trend ?? PriceTrend.unknown;
  }

  bool get isHistoricalLow {
    return intelligence?.isHistoricalLow ?? false;
  }

  bool get isHistoricalHigh {
    return intelligence?.isHistoricalHigh ?? false;
  }

  String get recommendationTitle {
    return intelligence?.recommendationTitle ?? 'More History Needed';
  }

  String get recommendationMessage {
    return intelligence?.recommendationMessage ??
        'SmartCart needs more price history before making a recommendation.';
  }

  String get confidenceLabel {
    return intelligence?.confidenceLabel ?? 'Low';
  }

  String get scoreLabel {
    if (intelligenceScore >= 85) {
      return 'Exceptional';
    }

    if (intelligenceScore >= 70) {
      return 'Strong';
    }

    if (intelligenceScore >= 55) {
      return 'Fair';
    }

    if (intelligenceScore >= 40) {
      return 'Weak';
    }

    return 'Wait';
  }

  String get scoreRecommendation {
    if (!hasIntelligence ||
        recommendation == BuyRecommendation.insufficientData) {
      return 'More data needed';
    }

    if (intelligenceScore >= 85) {
      return 'Buy now';
    }

    if (intelligenceScore >= 70) {
      return 'Good time to buy';
    }

    if (intelligenceScore >= 55) {
      return 'Fair price';
    }

    return 'Consider waiting';
  }
}

enum WatchlistInsightType {
  priceDrop,
  priceIncrease,
  lowestRecorded,
  stable,
  notEnoughData,
}

class WatchlistIntelligenceResult {
  final List<WatchlistInsight> insights;

  final int priceDrops;
  final int priceIncreases;
  final int productsAtLowestPrice;
  final int productsWithoutEnoughData;

  final int excellentBuys;
  final int goodBuys;
  final int fairPrices;
  final int waitRecommendations;

  final double totalPotentialSavings;
  final int averageIntelligenceScore;

  const WatchlistIntelligenceResult({
    required this.insights,
    required this.priceDrops,
    required this.priceIncreases,
    required this.productsAtLowestPrice,
    required this.productsWithoutEnoughData,
    required this.excellentBuys,
    required this.goodBuys,
    required this.fairPrices,
    required this.waitRecommendations,
    required this.totalPotentialSavings,
    required this.averageIntelligenceScore,
  });

  const WatchlistIntelligenceResult.empty()
    : insights = const [],
      priceDrops = 0,
      priceIncreases = 0,
      productsAtLowestPrice = 0,
      productsWithoutEnoughData = 0,
      excellentBuys = 0,
      goodBuys = 0,
      fairPrices = 0,
      waitRecommendations = 0,
      totalPotentialSavings = 0,
      averageIntelligenceScore = 0;

  bool get hasInsights => insights.isNotEmpty;

  int get actionableBuys {
    return excellentBuys + goodBuys;
  }

  int get analyzedProducts {
    return insights.length - productsWithoutEnoughData;
  }

  bool get hasBuyingOpportunities {
    return actionableBuys > 0;
  }

  bool get hasWaitRecommendations {
    return waitRecommendations > 0;
  }
}

class WatchlistIntelligenceService {
  static Future<WatchlistIntelligenceResult> loadWatchlistIntelligence() async {
    final favorites = await FavoritesService.getFavorites();

    final validFavorites = favorites.where((favorite) {
      final product = favorite.product;

      return product != null && product.barcode.trim().isNotEmpty;
    }).toList();

    if (validFavorites.isEmpty) {
      return const WatchlistIntelligenceResult.empty();
    }

    final barcodes = validFavorites
        .map((favorite) => favorite.product!.barcode.trim())
        .toSet()
        .toList();

    final results = await Future.wait<dynamic>([
      PriceIntelligenceService.analyzeProducts(barcodes: barcodes),
      Future.wait(
        validFavorites.map(
          (favorite) =>
              PriceHistoryService.getPriceHistory(favorite.product!.barcode),
        ),
      ),
    ]);

    final intelligenceByBarcode = results[0] as Map<String, PriceIntelligence>;

    final historySummaries = results[1] as List<PriceHistorySummary>;

    final insights = <WatchlistInsight>[];

    for (int index = 0; index < validFavorites.length; index++) {
      final favorite = validFavorites[index];
      final product = favorite.product!;
      final barcode = product.barcode.trim();
      final summary = historySummaries[index];
      final intelligence = intelligenceByBarcode[barcode];

      insights.add(
        _buildInsight(
          favorite: favorite,
          product: product,
          summary: summary,
          intelligence: intelligence,
        ),
      );
    }

    insights.sort(_compareInsights);

    return _buildResult(insights);
  }

  static WatchlistIntelligenceResult _buildResult(
    List<WatchlistInsight> insights,
  ) {
    int priceDrops = 0;
    int priceIncreases = 0;
    int productsAtLowestPrice = 0;
    int productsWithoutEnoughData = 0;

    int excellentBuys = 0;
    int goodBuys = 0;
    int fairPrices = 0;
    int waitRecommendations = 0;

    int totalScore = 0;
    int scoredProducts = 0;

    double totalPotentialSavings = 0;

    for (final insight in insights) {
      switch (insight.type) {
        case WatchlistInsightType.priceDrop:
          priceDrops++;
          break;

        case WatchlistInsightType.priceIncrease:
          priceIncreases++;
          break;

        case WatchlistInsightType.lowestRecorded:
          productsAtLowestPrice++;
          break;

        case WatchlistInsightType.notEnoughData:
          productsWithoutEnoughData++;
          break;

        case WatchlistInsightType.stable:
          break;
      }

      switch (insight.recommendation) {
        case BuyRecommendation.excellentBuy:
          excellentBuys++;
          break;

        case BuyRecommendation.goodBuy:
          goodBuys++;
          break;

        case BuyRecommendation.fairPrice:
          fairPrices++;
          break;

        case BuyRecommendation.wait:
          waitRecommendations++;
          break;

        case BuyRecommendation.insufficientData:
          break;
      }

      if (insight.hasIntelligence &&
          insight.recommendation != BuyRecommendation.insufficientData) {
        totalScore += insight.intelligenceScore;
        scoredProducts++;
      }

      totalPotentialSavings += insight.potentialSavings;
    }

    final averageScore = scoredProducts == 0
        ? 0
        : (totalScore / scoredProducts).round();

    return WatchlistIntelligenceResult(
      insights: insights,
      priceDrops: priceDrops,
      priceIncreases: priceIncreases,
      productsAtLowestPrice: productsAtLowestPrice,
      productsWithoutEnoughData: productsWithoutEnoughData,
      excellentBuys: excellentBuys,
      goodBuys: goodBuys,
      fairPrices: fairPrices,
      waitRecommendations: waitRecommendations,
      totalPotentialSavings: totalPotentialSavings,
      averageIntelligenceScore: averageScore,
    );
  }

  static WatchlistInsight _buildInsight({
    required FavoriteProduct favorite,
    required Product product,
    required PriceHistorySummary summary,
    required PriceIntelligence? intelligence,
  }) {
    if (intelligence == null ||
        intelligence.recommendation == BuyRecommendation.insufficientData) {
      return WatchlistInsight(
        favorite: favorite,
        product: product,
        summary: summary,
        intelligence: intelligence,
        headline: 'More price data needed',
        message: summary.hasData
            ? 'SmartCart has recorded a price for this '
                  'product, but more observations are needed '
                  'before it can provide reliable buying advice.'
            : 'Add a price or scan a receipt containing this '
                  'product to begin building its price history.',
        type: WatchlistInsightType.notEnoughData,
        intelligenceScore: 0,
        potentialSavings: 0,
      );
    }

    final score = _calculateIntelligenceScore(intelligence);

    final potentialSavings = _calculatePotentialSavings(intelligence);

    if (intelligence.isHistoricalLow) {
      return WatchlistInsight(
        favorite: favorite,
        product: product,
        summary: summary,
        intelligence: intelligence,
        headline: 'Excellent buy — historical low',
        message:
            'The current price of '
            '\$${intelligence.currentPrice.toStringAsFixed(2)} '
            'is the lowest recorded price. '
            '${_comparisonMessage(intelligence)}',
        type: WatchlistInsightType.lowestRecorded,
        intelligenceScore: score,
        potentialSavings: potentialSavings,
      );
    }

    switch (intelligence.recommendation) {
      case BuyRecommendation.excellentBuy:
        return WatchlistInsight(
          favorite: favorite,
          product: product,
          summary: summary,
          intelligence: intelligence,
          headline: 'Excellent buying opportunity',
          message: _buyMessage(intelligence, strongRecommendation: true),
          type: WatchlistInsightType.priceDrop,
          intelligenceScore: score,
          potentialSavings: potentialSavings,
        );

      case BuyRecommendation.goodBuy:
        return WatchlistInsight(
          favorite: favorite,
          product: product,
          summary: summary,
          intelligence: intelligence,
          headline: 'Good time to buy',
          message: _buyMessage(intelligence, strongRecommendation: false),
          type: intelligence.trend == PriceTrend.falling
              ? WatchlistInsightType.priceDrop
              : WatchlistInsightType.stable,
          intelligenceScore: score,
          potentialSavings: potentialSavings,
        );

      case BuyRecommendation.fairPrice:
        return WatchlistInsight(
          favorite: favorite,
          product: product,
          summary: summary,
          intelligence: intelligence,
          headline: 'Fair price',
          message:
              'The current price of '
              '\$${intelligence.currentPrice.toStringAsFixed(2)} '
              'is close to its historical average of '
              '\$${intelligence.averagePrice.toStringAsFixed(2)}. '
              '${_trendMessage(intelligence.trend)}',
          type: WatchlistInsightType.stable,
          intelligenceScore: score,
          potentialSavings: potentialSavings,
        );

      case BuyRecommendation.wait:
        return WatchlistInsight(
          favorite: favorite,
          product: product,
          summary: summary,
          intelligence: intelligence,
          headline: intelligence.isHistoricalHigh
              ? 'Consider waiting — historical high'
              : 'Consider waiting',
          message: _waitMessage(intelligence),
          type: WatchlistInsightType.priceIncrease,
          intelligenceScore: score,
          potentialSavings: potentialSavings,
        );

      case BuyRecommendation.insufficientData:
        return WatchlistInsight(
          favorite: favorite,
          product: product,
          summary: summary,
          intelligence: intelligence,
          headline: 'More price data needed',
          message:
              'SmartCart needs more recorded prices before '
              'it can confidently recommend buying or waiting.',
          type: WatchlistInsightType.notEnoughData,
          intelligenceScore: 0,
          potentialSavings: 0,
        );
    }
  }

  static String _buyMessage(
    PriceIntelligence intelligence, {
    required bool strongRecommendation,
  }) {
    final difference = intelligence.currentVsAveragePercent.abs();

    if (intelligence.currentVsAveragePercent < 0) {
      return 'The current price of '
          '\$${intelligence.currentPrice.toStringAsFixed(2)} '
          'is ${difference.toStringAsFixed(1)}% below its '
          'historical average. '
          '${_trendMessage(intelligence.trend)}';
    }

    if (intelligence.trend == PriceTrend.falling) {
      return 'The current price is '
          '\$${intelligence.currentPrice.toStringAsFixed(2)} '
          'and recent prices are trending downward.';
    }

    return strongRecommendation
        ? 'Historical pricing indicates that the current '
              'price of '
              '\$${intelligence.currentPrice.toStringAsFixed(2)} '
              'is an excellent buying opportunity.'
        : 'Historical pricing indicates that the current '
              'price of '
              '\$${intelligence.currentPrice.toStringAsFixed(2)} '
              'is better than usual.';
  }

  static String _waitMessage(PriceIntelligence intelligence) {
    final difference = intelligence.currentVsAveragePercent.abs();

    if (intelligence.isHistoricalHigh) {
      return 'The current price of '
          '\$${intelligence.currentPrice.toStringAsFixed(2)} '
          'is the highest recorded price. The historical '
          'average is '
          '\$${intelligence.averagePrice.toStringAsFixed(2)}.';
    }

    if (intelligence.currentVsAveragePercent > 0) {
      return 'The current price of '
          '\$${intelligence.currentPrice.toStringAsFixed(2)} '
          'is ${difference.toStringAsFixed(1)}% above its '
          'historical average. '
          '${_trendMessage(intelligence.trend)}';
    }

    return 'The current price of '
        '\$${intelligence.currentPrice.toStringAsFixed(2)} '
        'is not currently considered a strong buying '
        'opportunity.';
  }

  static String _comparisonMessage(PriceIntelligence intelligence) {
    final difference = intelligence.currentVsAveragePercent.abs();

    if (intelligence.currentVsAveragePercent < 0) {
      return 'That is ${difference.toStringAsFixed(1)}% '
          'below its historical average.';
    }

    return 'Its historical average is '
        '\$${intelligence.averagePrice.toStringAsFixed(2)}.';
  }

  static String _trendMessage(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.falling:
        return 'Recent prices are trending downward.';

      case PriceTrend.rising:
        return 'Recent prices are trending upward.';

      case PriceTrend.stable:
        return 'Recent prices have been relatively stable.';

      case PriceTrend.unknown:
        return 'There is not yet enough recent data to '
            'identify a clear trend.';
    }
  }

  static double _calculatePotentialSavings(PriceIntelligence intelligence) {
    if (intelligence.currentPrice >= intelligence.averagePrice) {
      return 0;
    }

    return intelligence.averagePrice - intelligence.currentPrice;
  }

  static int _calculateIntelligenceScore(PriceIntelligence intelligence) {
    double score;

    switch (intelligence.recommendation) {
      case BuyRecommendation.excellentBuy:
        score = 86;
        break;

      case BuyRecommendation.goodBuy:
        score = 72;
        break;

      case BuyRecommendation.fairPrice:
        score = 56;
        break;

      case BuyRecommendation.wait:
        score = 32;
        break;

      case BuyRecommendation.insufficientData:
        return 0;
    }

    if (intelligence.isHistoricalLow) {
      score += 10;
    }

    if (intelligence.isHistoricalHigh) {
      score -= 12;
    }

    final averageDifference = intelligence.currentVsAveragePercent;

    if (averageDifference <= -20) {
      score += 8;
    } else if (averageDifference <= -10) {
      score += 5;
    } else if (averageDifference <= -5) {
      score += 2;
    } else if (averageDifference >= 20) {
      score -= 8;
    } else if (averageDifference >= 10) {
      score -= 5;
    } else if (averageDifference >= 5) {
      score -= 2;
    }

    switch (intelligence.trend) {
      case PriceTrend.falling:
        score += 3;
        break;

      case PriceTrend.rising:
        score -= 3;
        break;

      case PriceTrend.stable:
      case PriceTrend.unknown:
        break;
    }

    if (intelligence.observations >= 20) {
      score += 3;
    } else if (intelligence.observations < 5) {
      score -= 3;
    }

    return score.clamp(0, 100).round();
  }

  static int _compareInsights(WatchlistInsight first, WatchlistInsight second) {
    final scoreComparison = second.intelligenceScore.compareTo(
      first.intelligenceScore,
    );

    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final priorityComparison = _priority(
      first.type,
    ).compareTo(_priority(second.type));

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final firstChange = first.summary.percentageChange.abs();

    final secondChange = second.summary.percentageChange.abs();

    final changeComparison = secondChange.compareTo(firstChange);

    if (changeComparison != 0) {
      return changeComparison;
    }

    return first.product.name.toLowerCase().compareTo(
      second.product.name.toLowerCase(),
    );
  }

  static int _priority(WatchlistInsightType type) {
    switch (type) {
      case WatchlistInsightType.lowestRecorded:
        return 0;

      case WatchlistInsightType.priceDrop:
        return 1;

      case WatchlistInsightType.stable:
        return 2;

      case WatchlistInsightType.priceIncrease:
        return 3;

      case WatchlistInsightType.notEnoughData:
        return 4;
    }
  }
}

import '../models/product.dart';
import 'favorites_service.dart';
import 'price_history_service.dart';

class WatchlistInsight {
  final FavoriteProduct favorite;
  final Product product;
  final PriceHistorySummary summary;
  final String headline;
  final String message;
  final WatchlistInsightType type;

  const WatchlistInsight({
    required this.favorite,
    required this.product,
    required this.summary,
    required this.headline,
    required this.message,
    required this.type,
  });

  bool get hasPriceData => summary.hasData;
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

  const WatchlistIntelligenceResult({
    required this.insights,
    required this.priceDrops,
    required this.priceIncreases,
    required this.productsAtLowestPrice,
    required this.productsWithoutEnoughData,
  });

  const WatchlistIntelligenceResult.empty()
    : insights = const [],
      priceDrops = 0,
      priceIncreases = 0,
      productsAtLowestPrice = 0,
      productsWithoutEnoughData = 0;

  bool get hasInsights => insights.isNotEmpty;
}

class WatchlistIntelligenceService {
  static Future<WatchlistIntelligenceResult> loadWatchlistIntelligence() async {
    final favorites = await FavoritesService.getFavorites();

    if (favorites.isEmpty) {
      return const WatchlistIntelligenceResult.empty();
    }

    final insights = <WatchlistInsight>[];

    int priceDrops = 0;
    int priceIncreases = 0;
    int productsAtLowestPrice = 0;
    int productsWithoutEnoughData = 0;

    for (final favorite in favorites) {
      final product = favorite.product;

      if (product == null) {
        continue;
      }

      final summary = await PriceHistoryService.getPriceHistory(
        product.barcode,
      );

      final insight = _buildInsight(
        favorite: favorite,
        product: product,
        summary: summary,
      );

      insights.add(insight);

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
    }

    insights.sort(_compareInsights);

    return WatchlistIntelligenceResult(
      insights: insights,
      priceDrops: priceDrops,
      priceIncreases: priceIncreases,
      productsAtLowestPrice: productsAtLowestPrice,
      productsWithoutEnoughData: productsWithoutEnoughData,
    );
  }

  static WatchlistInsight _buildInsight({
    required FavoriteProduct favorite,
    required Product product,
    required PriceHistorySummary summary,
  }) {
    if (!summary.hasData || summary.priceCount < 2) {
      return WatchlistInsight(
        favorite: favorite,
        product: product,
        summary: summary,
        headline: 'More price data needed',
        message: summary.hasData
            ? 'Add another price or scan another receipt containing this product '
                  'to begin tracking changes.'
            : 'Add a price or scan a receipt containing this product '
                  'to begin tracking changes.',
        type: WatchlistInsightType.notEnoughData,
      );
    }

    final isAtLowestPrice =
        (summary.currentPrice - summary.lowestPrice).abs() < 0.01;

    if (isAtLowestPrice && summary.priceCount > 1) {
      return WatchlistInsight(
        favorite: favorite,
        product: product,
        summary: summary,
        headline: 'At its lowest recorded price',
        message:
            '${_displayStore(summary.mostRecentStore)} currently has this product at '
            '\$${summary.currentPrice.toStringAsFixed(2)}.',
        type: WatchlistInsightType.lowestRecorded,
      );
    }

    if (summary.trend.toLowerCase() == 'falling') {
      return WatchlistInsight(
        favorite: favorite,
        product: product,
        summary: summary,
        headline: 'Price dropped',
        message:
            'The latest price fell ${summary.percentageChange.abs().toStringAsFixed(1)}% '
            'to \$${summary.currentPrice.toStringAsFixed(2)} at '
            '${_displayStore(summary.mostRecentStore)}.',
        type: WatchlistInsightType.priceDrop,
      );
    }

    if (summary.trend.toLowerCase() == 'rising') {
      return WatchlistInsight(
        favorite: favorite,
        product: product,
        summary: summary,
        headline: 'Price increased',
        message:
            'The latest price rose ${summary.percentageChange.abs().toStringAsFixed(1)}% '
            'to \$${summary.currentPrice.toStringAsFixed(2)} at '
            '${_displayStore(summary.mostRecentStore)}.',
        type: WatchlistInsightType.priceIncrease,
      );
    }

    return WatchlistInsight(
      favorite: favorite,
      product: product,
      summary: summary,
      headline: 'Price is stable',
      message:
          'The latest recorded price is \$${summary.currentPrice.toStringAsFixed(2)}. '
          'The best recorded store is ${_displayStore(summary.bestStore)}.',
      type: WatchlistInsightType.stable,
    );
  }

  static int _compareInsights(WatchlistInsight a, WatchlistInsight b) {
    final priorityComparison = _priority(a.type).compareTo(_priority(b.type));

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final aChange = a.summary.percentageChange.abs();
    final bChange = b.summary.percentageChange.abs();

    return bChange.compareTo(aChange);
  }

  static int _priority(WatchlistInsightType type) {
    switch (type) {
      case WatchlistInsightType.lowestRecorded:
        return 0;
      case WatchlistInsightType.priceDrop:
        return 1;
      case WatchlistInsightType.priceIncrease:
        return 2;
      case WatchlistInsightType.stable:
        return 3;
      case WatchlistInsightType.notEnoughData:
        return 4;
    }
  }

  static String _displayStore(String storeName) {
    final cleanedName = storeName.trim();

    if (cleanedName.isEmpty || cleanedName.toLowerCase() == 'not available') {
      return 'an unknown store';
    }

    return cleanedName;
  }
}

import '../models/savings_summary.dart';
import '../service/watchlist_intelligence_service.dart';

class SavingsSummaryService {
  static Future<SavingsSummary> loadSavingsSummary() async {
    final result =
        await WatchlistIntelligenceService.loadWatchlistIntelligence();

    if (!result.hasInsights) {
      return const SavingsSummary.empty();
    }

    double potentialSavings = 0;
    int productsCompared = 0;
    SavingsHighlight? bestDeal;

    for (final insight in result.insights) {
      final summary = insight.summary;

      if (!summary.hasData || summary.priceCount < 2) {
        continue;
      }

      productsCompared++;

      final amountSaved = summary.currentPrice - summary.lowestPrice;

      if (amountSaved <= 0.01) {
        continue;
      }

      potentialSavings += amountSaved;

      final highlight = SavingsHighlight(
        productName: insight.product.name,
        storeName: _displayStore(summary.bestStore),
        amountSaved: amountSaved,
        purchasePrice: summary.currentPrice,
        comparisonPrice: summary.lowestPrice,
      );

      if (bestDeal == null || highlight.amountSaved > bestDeal.amountSaved) {
        bestDeal = highlight;
      }
    }

    return SavingsSummary(
      totalSavings: 0,
      watchlistSavingsPotential: potentialSavings,
      priceDropCount: result.priceDrops,
      purchasesCompared: productsCompared,
      bestDeal: bestDeal,
    );
  }

  static String _displayStore(String storeName) {
    final cleanedName = storeName.trim();

    if (cleanedName.isEmpty || cleanedName.toLowerCase() == 'not available') {
      return 'Unknown store';
    }

    return cleanedName;
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/product.dart';
import '../service/favorites_service.dart';
import '../service/watchlist_intelligence_service.dart';
import '../widgets/favorites/watchlist_empty_state.dart';
import '../widgets/favorites/watchlist_error_state.dart';
import '../widgets/favorites/watchlist_filter_bar.dart';
import '../widgets/favorites/watchlist_header.dart';
import '../widgets/favorites/watchlist_insight_card.dart';
import '../widgets/favorites/watchlist_loading.dart';
import '../widgets/favorites/watchlist_sort_bar.dart';
import '../widgets/favorites/watchlist_summary_card.dart';
import 'product_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  WatchlistIntelligenceResult result =
      const WatchlistIntelligenceResult.empty();

  WatchlistFilter selectedFilter = WatchlistFilter.all;
  WatchlistSort selectedSort = WatchlistSort.biggestDrop;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadWatchlist();
  }

  Future<void> loadWatchlist() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedResult =
          await WatchlistIntelligenceService.loadWatchlistIntelligence();

      if (!mounted) {
        return;
      }

      setState(() {
        result = loadedResult;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage =
            'Rocket Science Shopping could not load your watchlist right now. '
            'Check your connection and try again.';
      });
    }
  }

  Future<void> openProduct(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
    );

    if (!mounted) {
      return;
    }

    await loadWatchlist();
  }

  Future<void> removeFavorite(WatchlistInsight insight) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove from favourites?'),
          content: Text(
            '${displayProductName(insight)} will be removed '
            'from your Rocket Science Shopping watchlist.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true || !mounted) {
      return;
    }

    try {
      await FavoritesService.removeFavorite(insight.product.barcode);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${displayProductName(insight)} removed from favourites.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await loadWatchlist();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rocket Science Shopping could not remove this favourite. '
            'Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String displayProductName(WatchlistInsight insight) {
    final product = insight.product;

    final parts = [
      product.brand,
      product.name,
      product.size,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return product.barcode;
    }

    return parts.join(' ');
  }

  int countInsights(WatchlistInsightType type) {
    return result.insights.where((insight) => insight.type == type).length;
  }

  List<WatchlistInsight> get visibleInsights {
    final insights = result.insights.where(selectedFilter.matches).toList();

    insights.sort(compareInsights);

    return insights;
  }

  int compareInsights(WatchlistInsight a, WatchlistInsight b) {
    final primaryComparison = switch (selectedSort) {
      WatchlistSort.biggestDrop => compareBiggestDrop(a, b),
      WatchlistSort.biggestIncrease => compareBiggestIncrease(a, b),
      WatchlistSort.lowestCurrentPrice => compareLowestPrice(a, b),
      WatchlistSort.recentlyUpdated => compareRecentlyUpdated(a, b),
      WatchlistSort.productName => compareProductName(a, b),
    };

    if (primaryComparison != 0) {
      return primaryComparison;
    }

    final scoreComparison = b.intelligenceScore.compareTo(a.intelligenceScore);

    if (scoreComparison != 0) {
      return scoreComparison;
    }

    return compareProductName(a, b);
  }

  int compareBiggestDrop(WatchlistInsight a, WatchlistInsight b) {
    final dataComparison = comparePriceData(a, b);

    if (dataComparison != 0) {
      return dataComparison;
    }

    return a.summary.percentageChange.compareTo(b.summary.percentageChange);
  }

  int compareBiggestIncrease(WatchlistInsight a, WatchlistInsight b) {
    final dataComparison = comparePriceData(a, b);

    if (dataComparison != 0) {
      return dataComparison;
    }

    return b.summary.percentageChange.compareTo(a.summary.percentageChange);
  }

  int compareLowestPrice(WatchlistInsight a, WatchlistInsight b) {
    final dataComparison = comparePriceData(a, b);

    if (dataComparison != 0) {
      return dataComparison;
    }

    return a.summary.currentPrice.compareTo(b.summary.currentPrice);
  }

  int compareRecentlyUpdated(WatchlistInsight a, WatchlistInsight b) {
    final aDate = a.summary.lastUpdated;
    final bDate = b.summary.lastUpdated;

    if (aDate == null && bDate == null) {
      return compareProductName(a, b);
    }

    if (aDate == null) {
      return 1;
    }

    if (bDate == null) {
      return -1;
    }

    return bDate.compareTo(aDate);
  }

  int compareProductName(WatchlistInsight a, WatchlistInsight b) {
    return displayProductName(
      a,
    ).toLowerCase().compareTo(displayProductName(b).toLowerCase());
  }

  int comparePriceData(WatchlistInsight a, WatchlistInsight b) {
    if (a.hasPriceData && !b.hasPriceData) {
      return -1;
    }

    if (!a.hasPriceData && b.hasPriceData) {
      return 1;
    }

    return 0;
  }

  void updateFilter(WatchlistFilter filter) {
    setState(() {
      selectedFilter = filter;
    });
  }

  void updateSort(WatchlistSort sort) {
    setState(() {
      selectedSort = sort;
    });
  }

  Color get overallScoreColor {
    final score = result.averageIntelligenceScore;

    if (score >= 85) {
      return AppColors.success;
    }

    if (score >= 70) {
      return Colors.green.shade700;
    }

    if (score >= 55) {
      return Colors.blue.shade700;
    }

    if (score >= 40) {
      return Colors.orange.shade800;
    }

    return Colors.red.shade700;
  }

  String get overallScoreLabel {
    final score = result.averageIntelligenceScore;

    if (result.analyzedProducts == 0) {
      return 'Building history';
    }

    if (score >= 85) {
      return 'Exceptional opportunities';
    }

    if (score >= 70) {
      return 'Strong buying conditions';
    }

    if (score >= 55) {
      return 'Fair buying conditions';
    }

    if (score >= 40) {
      return 'Mixed buying conditions';
    }

    return 'Consider waiting';
  }

  String get watchlistGuidance {
    if (result.analyzedProducts == 0) {
      return 'Rocket Science Shopping is collecting price history for your '
          'favourites. More observations will unlock personalized '
          'buying recommendations.';
    }

    if (result.excellentBuys > 0) {
      final label = result.excellentBuys == 1 ? 'item is' : 'items are';

      return '${result.excellentBuys} $label currently rated as '
          'an excellent buy. These are your strongest opportunities.';
    }

    if (result.goodBuys > 0) {
      final label = result.goodBuys == 1 ? 'item' : 'items';

      return '${result.goodBuys} $label currently offer better-than-usual '
          'value based on recorded price history.';
    }

    if (result.waitRecommendations > 0) {
      final label = result.waitRecommendations == 1 ? 'item is' : 'items are';

      return '${result.waitRecommendations} $label priced higher than '
          'Rocket Science Shopping would normally recommend paying.';
    }

    return 'Most watched products are currently close to their '
        'historical averages.';
  }

  String get insightsSectionTitle {
    switch (selectedFilter) {
      case WatchlistFilter.all:
        return 'Latest Insights';

      case WatchlistFilter.priceDrops:
        return 'Price Drops';

      case WatchlistFilter.priceIncreases:
        return 'Price Increases';

      case WatchlistFilter.lowestPrice:
        return 'Historical Lows';

      case WatchlistFilter.stable:
        return 'Stable Prices';

      case WatchlistFilter.moreDataNeeded:
        return 'Building Price History';
    }
  }

  Widget buildIntelligenceDashboard() {
    final scoreColor = overallScoreColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.13),
            scoreColor.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rocket Science Shopping Intelligence',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Personalized guidance based on recorded prices',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              buildOverallScore(scoreColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            overallScoreLabel,
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            watchlistGuidance,
            style: const TextStyle(height: 1.4, color: Colors.black87),
          ),
          const SizedBox(height: 17),
          buildOpportunityGrid(),
          if (result.totalPotentialSavings > 0) ...[
            const SizedBox(height: 14),
            buildSavingsBanner(),
          ],
          if (result.productsWithoutEnoughData > 0) ...[
            const SizedBox(height: 12),
            buildHistoryNotice(),
          ],
        ],
      ),
    );
  }

  Widget buildOverallScore(Color color) {
    if (result.analyzedProducts == 0) {
      return Container(
        width: 70,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.18)),
        ),
        child: const Column(
          children: [
            Icon(Icons.query_stats, size: 22, color: Colors.blueGrey),
            SizedBox(height: 3),
            Text(
              'N/A',
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Score',
              style: TextStyle(color: Colors.black54, fontSize: 10),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            '${result.averageIntelligenceScore}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '/ 100',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Average',
            style: TextStyle(color: Colors.black54, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget buildOpportunityGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: buildIntelligenceMetric(
                icon: Icons.workspace_premium,
                label: 'Excellent Buys',
                value: '${result.excellentBuys}',
                color: AppColors.success,
              ),
            ),
            SizedBox(
              width: width,
              child: buildIntelligenceMetric(
                icon: Icons.thumb_up_alt_outlined,
                label: 'Good Buys',
                value: '${result.goodBuys}',
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(
              width: width,
              child: buildIntelligenceMetric(
                icon: Icons.balance_outlined,
                label: 'Fair Prices',
                value: '${result.fairPrices}',
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(
              width: width,
              child: buildIntelligenceMetric(
                icon: Icons.schedule,
                label: 'Consider Waiting',
                value: '${result.waitRecommendations}',
                color: Colors.orange.shade800,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildIntelligenceMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSavingsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.19)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.savings_outlined,
            color: AppColors.success,
            size: 27,
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings versus average',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Combined value below recorded average prices',
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '\$${result.totalPotentialSavings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHistoryNotice() {
    final count = result.productsWithoutEnoughData;
    final productLabel = count == 1 ? 'product needs' : 'products need';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$count $productLabel more recorded prices before '
            'Rocket Science Shopping can provide confident buying advice.',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget filteredEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          children: [
            const Icon(Icons.filter_alt_off, size: 52),
            const SizedBox(height: 14),
            const Text(
              'No Matching Insights',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are currently no watchlist items '
              'in this category.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                updateFilter(WatchlistFilter.all);
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Show All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget watchlistContent() {
    if (isLoading) {
      return const WatchlistLoading();
    }

    if (errorMessage != null) {
      return WatchlistErrorState(
        message: errorMessage!,
        onRetry: loadWatchlist,
      );
    }

    if (!result.hasInsights) {
      return WatchlistEmptyState(onRefresh: loadWatchlist);
    }

    final insights = visibleInsights;

    final priceDropCount = countInsights(WatchlistInsightType.priceDrop);

    final priceIncreaseCount = countInsights(
      WatchlistInsightType.priceIncrease,
    );

    final lowestPriceCount = countInsights(WatchlistInsightType.lowestRecorded);

    final stableCount = countInsights(WatchlistInsightType.stable);

    final needsDataCount = countInsights(WatchlistInsightType.notEnoughData);

    return RefreshIndicator(
      onRefresh: loadWatchlist,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          WatchlistHeader(totalProducts: result.insights.length),
          const SizedBox(height: 18),
          buildIntelligenceDashboard(),
          const SizedBox(height: 18),
          WatchlistSummaryCard(
            totalProducts: result.insights.length,
            priceDrops: priceDropCount,
            priceIncreases: priceIncreaseCount,
            lowestPrices: lowestPriceCount,
          ),
          const SizedBox(height: 22),
          WatchlistFilterBar(
            selectedFilter: selectedFilter,
            onChanged: updateFilter,
            totalCount: result.insights.length,
            priceDropCount: priceDropCount,
            priceIncreaseCount: priceIncreaseCount,
            lowestPriceCount: lowestPriceCount,
            stableCount: stableCount,
            needsDataCount: needsDataCount,
          ),
          const SizedBox(height: 16),
          WatchlistSortBar(selectedSort: selectedSort, onChanged: updateSort),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  insightsSectionTitle,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${insights.length} shown',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            filteredEmptyState()
          else
            ...insights.map(
              (insight) => WatchlistInsightCard(
                insight: insight,
                onTap: () {
                  openProduct(insight.product);
                },
                onRemove: () {
                  removeFavorite(insight);
                },
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadWatchlist,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Watchlist',
          ),
        ],
      ),
      body: watchlistContent(),
    );
  }
}

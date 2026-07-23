import 'package:flutter/material.dart';

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

      if (!mounted) return;

      setState(() {
        result = loadedResult;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load favourites: $error';
      });
    }
  }

  Future<void> openProduct(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
    );

    if (!mounted) return;

    await loadWatchlist();
  }

  Future<void> removeFavorite(WatchlistInsight insight) async {
    try {
      await FavoritesService.removeFavorite(insight.product.barcode);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${insight.product.name} removed from favourites.'),
        ),
      );

      await loadWatchlist();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove favourite: $error')),
      );
    }
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
    switch (selectedSort) {
      case WatchlistSort.biggestDrop:
        return compareBiggestDrop(a, b);

      case WatchlistSort.biggestIncrease:
        return compareBiggestIncrease(a, b);

      case WatchlistSort.lowestCurrentPrice:
        return compareLowestPrice(a, b);

      case WatchlistSort.recentlyUpdated:
        return compareRecentlyUpdated(a, b);

      case WatchlistSort.productName:
        return a.product.name.toLowerCase().compareTo(
          b.product.name.toLowerCase(),
        );
    }
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
      return a.product.name.toLowerCase().compareTo(
        b.product.name.toLowerCase(),
      );
    }

    if (aDate == null) {
      return 1;
    }

    if (bDate == null) {
      return -1;
    }

    return bDate.compareTo(aDate);
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
              'There are currently no watchlist items in this category.',
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
              const Expanded(
                child: Text(
                  'Latest Insights',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${insights.length} shown',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
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

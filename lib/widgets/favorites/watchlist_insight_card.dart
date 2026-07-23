import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../service/watchlist_intelligence_service.dart';
import '../store/store_badge.dart';
import 'price_sparkline.dart';

class WatchlistInsightCard extends StatelessWidget {
  final WatchlistInsight insight;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const WatchlistInsightCard({
    super.key,
    required this.insight,
    required this.onTap,
    required this.onRemove,
  });

  IconData get insightIcon {
    switch (insight.type) {
      case WatchlistInsightType.lowestRecorded:
        return Icons.local_offer;
      case WatchlistInsightType.priceDrop:
        return Icons.trending_down;
      case WatchlistInsightType.priceIncrease:
        return Icons.trending_up;
      case WatchlistInsightType.stable:
        return Icons.trending_flat;
      case WatchlistInsightType.notEnoughData:
        return Icons.info_outline;
    }
  }

  Color get insightColor {
    switch (insight.type) {
      case WatchlistInsightType.lowestRecorded:
        return AppColors.primary;
      case WatchlistInsightType.priceDrop:
        return AppColors.success;
      case WatchlistInsightType.priceIncrease:
        return Colors.red;
      case WatchlistInsightType.stable:
        return AppColors.warning;
      case WatchlistInsightType.notEnoughData:
        return Colors.grey;
    }
  }

  Widget productImage() {
    final product = insight.product;

    if (product.imageUrl.trim().isEmpty) {
      return const Icon(Icons.shopping_bag, size: 34, color: AppColors.primary);
    }

    return Image.network(
      product.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return const Icon(
          Icons.shopping_bag,
          size: 34,
          color: AppColors.primary,
        );
      },
    );
  }

  String get productName {
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

  String get currentPriceText {
    if (!insight.summary.hasData) {
      return 'No price data';
    }

    return '\$${insight.summary.currentPrice.toStringAsFixed(2)}';
  }

  String get changeText {
    if (!insight.summary.hasData) {
      return '';
    }

    final change = insight.summary.percentageChange;

    if (change.abs() < 0.01) {
      return 'No change';
    }

    final prefix = change > 0 ? '+' : '';

    return '$prefix${change.toStringAsFixed(1)}%';
  }

  String get displayStoreName {
    final recentStore = insight.summary.mostRecentStore.trim();

    if (recentStore.isNotEmpty &&
        recentStore.toLowerCase() != 'not available') {
      return recentStore;
    }

    final bestStore = insight.summary.bestStore.trim();

    if (bestStore.isNotEmpty && bestStore.toLowerCase() != 'not available') {
      return bestStore;
    }

    return 'Unknown Store';
  }

  bool get shouldShowStoreBadge {
    return insight.summary.hasData;
  }

  @override
  Widget build(BuildContext context) {
    final color = insightColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Center(child: productImage()),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(insightIcon, size: 17, color: color),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      insight.headline,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (shouldShowStoreBadge)
                              StoreBadge(
                                storeName: displayStoreName,
                                compact: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove from favourites',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(insight.message, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentPriceText,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (changeText.isNotEmpty)
                          Text(
                            changeText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PriceSparkline(
                      entries: insight.summary.entries,
                      height: 52,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

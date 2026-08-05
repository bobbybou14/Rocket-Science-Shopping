import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/price_intelligence.dart';
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
    switch (insight.recommendation) {
      case BuyRecommendation.excellentBuy:
        return AppColors.success;
      case BuyRecommendation.goodBuy:
        return Colors.green.shade700;
      case BuyRecommendation.fairPrice:
        return Colors.blue.shade700;
      case BuyRecommendation.wait:
        return Colors.orange.shade800;
      case BuyRecommendation.insufficientData:
        return Colors.blueGrey;
    }
  }

  IconData get recommendationIcon {
    switch (insight.recommendation) {
      case BuyRecommendation.excellentBuy:
        return Icons.workspace_premium;
      case BuyRecommendation.goodBuy:
        return Icons.thumb_up_alt;
      case BuyRecommendation.fairPrice:
        return Icons.balance;
      case BuyRecommendation.wait:
        return Icons.schedule;
      case BuyRecommendation.insufficientData:
        return Icons.query_stats;
    }
  }

  IconData get trendIcon {
    switch (insight.priceTrend) {
      case PriceTrend.falling:
        return Icons.trending_down;
      case PriceTrend.rising:
        return Icons.trending_up;
      case PriceTrend.stable:
        return Icons.trending_flat;
      case PriceTrend.unknown:
        return Icons.horizontal_rule;
    }
  }

  Color get trendColor {
    switch (insight.priceTrend) {
      case PriceTrend.falling:
        return AppColors.success;
      case PriceTrend.rising:
        return Colors.red.shade700;
      case PriceTrend.stable:
        return Colors.blueGrey;
      case PriceTrend.unknown:
        return Colors.grey;
    }
  }

  String get trendLabel {
    switch (insight.priceTrend) {
      case PriceTrend.falling:
        return 'Falling';
      case PriceTrend.rising:
        return 'Rising';
      case PriceTrend.stable:
        return 'Stable';
      case PriceTrend.unknown:
        return 'Unknown';
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
    final intelligence = insight.intelligence;

    if (intelligence != null) {
      return '\$${intelligence.currentPrice.toStringAsFixed(2)}';
    }

    if (!insight.summary.hasData) {
      return 'No price data';
    }

    return '\$${insight.summary.currentPrice.toStringAsFixed(2)}';
  }

  String get averagePriceText {
    final intelligence = insight.intelligence;

    if (intelligence == null) {
      return 'Not available';
    }

    return '\$${intelligence.averagePrice.toStringAsFixed(2)}';
  }

  String get lowestPriceText {
    final intelligence = insight.intelligence;

    if (intelligence == null) {
      return 'Not available';
    }

    return '\$${intelligence.lowestPrice.toStringAsFixed(2)}';
  }

  String get changeText {
    if (!insight.summary.hasData) {
      return '';
    }

    final change = insight.summary.percentageChange;

    if (change.abs() < 0.01) {
      return 'No recent change';
    }

    final prefix = change > 0 ? '+' : '';

    return '$prefix${change.toStringAsFixed(1)}%';
  }

  Color get changeColor {
    if (!insight.summary.hasData) {
      return Colors.black54;
    }

    final change = insight.summary.percentageChange;

    if (change < -0.01) {
      return AppColors.success;
    }

    if (change > 0.01) {
      return Colors.red.shade700;
    }

    return Colors.blueGrey;
  }

  String get comparisonText {
    final intelligence = insight.intelligence;

    if (intelligence == null) {
      return 'More price history is needed';
    }

    final percentage = intelligence.currentVsAveragePercent
        .abs()
        .toStringAsFixed(1);

    if (intelligence.currentVsAveragePercent < -0.01) {
      return '$percentage% below average';
    }

    if (intelligence.currentVsAveragePercent > 0.01) {
      return '$percentage% above average';
    }

    return 'At historical average';
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

  Widget _buildScoreBadge() {
    final color = insightColor;

    if (!insight.hasIntelligence ||
        insight.recommendation == BuyRecommendation.insufficientData) {
      return Container(
        width: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.18)),
        ),
        child: const Column(
          children: [
            Icon(Icons.query_stats, color: Colors.blueGrey, size: 22),
            SizedBox(height: 4),
            Text(
              'N/A',
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 15,
                fontWeight: FontWeight.bold,
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
      width: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            '${insight.intelligenceScore}',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
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
          Text(
            insight.scoreLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationBanner() {
    final color = insightColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(recommendationIcon, color: color, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.scoreRecommendation,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.recommendationTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (insight.hasIntelligence)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${insight.confidenceLabel} confidence',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoricalBadges() {
    final badges = <Widget>[];

    if (insight.isHistoricalLow) {
      badges.add(
        _buildStatusBadge(
          icon: Icons.south,
          label: 'HISTORICAL LOW',
          color: AppColors.success,
        ),
      );
    }

    if (insight.isHistoricalHigh) {
      badges.add(
        _buildStatusBadge(
          icon: Icons.north,
          label: 'HISTORICAL HIGH',
          color: Colors.red.shade700,
        ),
      );
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: badges),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceMetric({required String label, required String value}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPricePanel() {
    final color = insightColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current price',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentPriceText,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (changeText.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      changeText,
                      style: TextStyle(
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comparisonText,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (insight.hasIntelligence) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 11),
            Row(
              children: [
                _buildPriceMetric(
                  label: 'Historical average',
                  value: averagePriceText,
                ),
                const SizedBox(width: 12),
                _buildPriceMetric(
                  label: 'Recorded low',
                  value: lowestPriceText,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PriceSparkline(entries: insight.summary.entries, height: 52),
        ],
      ),
    );
  }

  Widget _buildIntelligenceDetails() {
    if (!insight.hasIntelligence) {
      return const SizedBox.shrink();
    }

    final intelligence = insight.intelligence!;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: trendIcon,
            iconColor: trendColor,
            label: 'Price trend',
            value: trendLabel,
          ),
          const SizedBox(height: 9),
          _buildDetailRow(
            icon: Icons.storage_outlined,
            iconColor: Colors.blueGrey,
            label: 'Price observations',
            value: '${intelligence.observations}',
          ),
          const SizedBox(height: 9),
          _buildDetailRow(
            icon: Icons.storefront_outlined,
            iconColor: Colors.blueGrey,
            label: 'Stores represented',
            value: '${intelligence.storeCount}',
          ),
          if (insight.potentialSavings > 0) ...[
            const SizedBox(height: 9),
            _buildDetailRow(
              icon: Icons.savings_outlined,
              iconColor: AppColors.success,
              label: 'Savings vs. average',
              value: '\$${insight.potentialSavings.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = insightColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
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
                    const SizedBox(width: 13),
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
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(insightIcon, size: 16, color: color),
                                    const SizedBox(width: 5),
                                    Text(
                                      insight.headline,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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
                    const SizedBox(width: 9),
                    Column(
                      children: [
                        _buildScoreBadge(),
                        const SizedBox(height: 4),
                        IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove from favourites',
                        ),
                      ],
                    ),
                  ],
                ),
                _buildHistoricalBadges(),
                const SizedBox(height: 13),
                _buildRecommendationBanner(),
                const SizedBox(height: 12),
                Text(insight.message, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 14),
                _buildPricePanel(),
                _buildIntelligenceDetails(),
                const SizedBox(height: 11),
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Tap to view product details and full price history',
                        style: TextStyle(color: Colors.black45, fontSize: 11),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

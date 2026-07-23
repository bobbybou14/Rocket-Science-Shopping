import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../service/favorites_service.dart';
import '../../service/price_history_service.dart';

class FavoriteProductCard extends StatelessWidget {
  final FavoriteProduct favorite;
  final Product product;
  final PriceHistorySummary summary;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const FavoriteProductCard({
    super.key,
    required this.favorite,
    required this.product,
    required this.summary,
    required this.onTap,
    required this.onRemove,
  });

  String get productName {
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

  IconData get trendIcon {
    switch (summary.trend.toLowerCase()) {
      case 'falling':
        return Icons.trending_down;
      case 'rising':
        return Icons.trending_up;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.show_chart;
    }
  }

  Color get trendColor {
    switch (summary.trend.toLowerCase()) {
      case 'falling':
        return AppColors.success;
      case 'rising':
        return Colors.red;
      case 'stable':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  Widget productImage() {
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

  @override
  Widget build(BuildContext context) {
    final hasPrice = summary.hasData;

    final percentPrefix = summary.percentageChange > 0 ? '+' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
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
                    const SizedBox(height: 5),
                    Text(
                      product.category.trim().isEmpty
                          ? 'No category'
                          : product.category,
                    ),
                    const SizedBox(height: 10),
                    if (hasPrice) ...[
                      Text(
                        '\$${summary.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(trendIcon, size: 19, color: trendColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${summary.trend} '
                              '($percentPrefix${summary.percentageChange.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: trendColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text('Best store: ${summary.bestStore}'),
                    ] else
                      const Text(
                        'No recorded price history yet.',
                        style: TextStyle(fontStyle: FontStyle.italic),
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
        ),
      ),
    );
  }
}

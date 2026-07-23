import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/store_branding.dart';
import '../service/basket_comparison_service.dart';

class StoreComparisonCard extends StatelessWidget {
  final BasketStoreComparison store;
  final bool isCheapest;
  final double potentialSavings;

  const StoreComparisonCard({
    super.key,
    required this.store,
    required this.isCheapest,
    required this.potentialSavings,
  });

  String get location {
    return [
      store.city,
      store.province,
    ].where((value) => value.trim().isNotEmpty).join(', ');
  }

  String get coverageText {
    final totalItems = store.pricedItems + store.missingItems;

    return '${store.pricedItems} of $totalItems items found';
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = store.isComplete;
    final branding = StoreBranding.fromStoreName(store.storeName);

    final statusColor = isCheapest
        ? AppColors.success
        : isComplete
        ? branding.primaryColor
        : AppColors.warning;

    final statusBackground = isCheapest
        ? AppColors.success.withValues(alpha: 0.12)
        : isComplete
        ? branding.backgroundColor
        : AppColors.warning.withValues(alpha: 0.12);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(18),
        childrenPadding: const EdgeInsets.only(left: 18, right: 18, bottom: 18),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: statusBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.30)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(branding.icon, color: branding.primaryColor, size: 30),
              if (isCheapest)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              if (!isComplete && !isCheapest)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.priority_high,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCheapest)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              branding.displayName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: branding.primaryColor,
              ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(location, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isComplete ? 'Complete Basket' : 'Partial Basket',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isComplete ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(height: 4),
              Text(coverageText),
              if (!isComplete)
                Text(
                  '${store.missingItems} item'
                  '${store.missingItems == 1 ? '' : 's'} missing',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 105,
          child: Text(
            store.total <= 0
                ? 'No total'
                : '\$${store.total.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isCheapest ? AppColors.success : branding.primaryColor,
            ),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: branding.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: branding.primaryColor.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Icon(branding.icon, color: branding.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isComplete
                        ? '${branding.displayName} complete basket total: '
                              '\$${store.total.toStringAsFixed(2)}'
                        : '${branding.displayName} partial basket total: '
                              '\$${store.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: branding.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCheapest && potentialSavings > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Potential savings compared with the highest complete basket: '
                '\$${potentialSavings.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (!isComplete)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'This store is not eligible for cheapest-basket ranking '
                'because one or more item prices are missing.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ...store.items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.hasPrice ? Icons.check_circle : Icons.warning_amber,
                color: item.hasPrice ? AppColors.success : AppColors.warning,
              ),
              title: Text(item.productName),
              subtitle: Text('Quantity: ${item.quantity.toStringAsFixed(0)}'),
              trailing: item.hasPrice
                  ? Text(
                      '\$${item.lineTotal!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: branding.primaryColor,
                      ),
                    )
                  : const Text(
                      'Missing',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

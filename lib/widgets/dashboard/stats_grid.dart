import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StatsGrid extends StatelessWidget {
  final int tripCount;
  final int storeCount;
  final double amountSpent;
  final double averageTripCost;

  const StatsGrid({
    super.key,
    required this.tripCount,
    required this.storeCount,
    required this.amountSpent,
    required this.averageTripCost,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final columnCount = isNarrow ? 2 : 4;

        return GridView.count(
          crossAxisCount: columnCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isNarrow ? 0.95 : 1.18,
          children: [
            _StatTile(
              icon: Icons.shopping_bag_outlined,
              label: 'Shopping Trips',
              value: tripCount.toString(),
              supportingText: 'This month',
            ),
            _StatTile(
              icon: Icons.store_outlined,
              label: 'Stores Visited',
              value: storeCount.toString(),
              supportingText: 'This month',
            ),
            _StatTile(
              icon: Icons.payments_outlined,
              label: 'Amount Spent',
              value: '\$${amountSpent.toStringAsFixed(2)}',
              supportingText: 'On groceries',
            ),
            _StatTile(
              icon: Icons.receipt_long_outlined,
              label: 'Average Trip',
              value: '\$${averageTripCost.toStringAsFixed(2)}',
              supportingText: 'Per shopping trip',
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String supportingText;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.supportingText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.primary, size: 25),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              supportingText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

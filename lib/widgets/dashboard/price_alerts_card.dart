import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/store_branding.dart';
import '../../service/dashboard_intelligence_service.dart';

class PriceAlertsCard extends StatelessWidget {
  final List<DashboardPriceAlert> alerts;

  const PriceAlertsCard({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: AppColors.primary,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price Alerts',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Recent price changes on products you track',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (alerts.isEmpty)
              const _EmptyAlertsState()
            else
              ...alerts.map((alert) => _PriceAlertTile(alert: alert)),
          ],
        ),
      ),
    );
  }
}

class _PriceAlertTile extends StatelessWidget {
  final DashboardPriceAlert alert;

  const _PriceAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isDrop = alert.isPriceDrop;

    final changeColor = isDrop ? AppColors.success : Colors.red;

    final changeIcon = isDrop ? Icons.trending_down : Icons.trending_up;

    final branding = StoreBranding.fromStoreName(alert.storeName);

    final sign = alert.percentageChange > 0 ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: changeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: changeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: branding.backgroundColor,
            child: Icon(branding.icon, color: branding.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  branding.displayName,
                  style: TextStyle(
                    color: branding.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '\$${alert.previousPrice.toStringAsFixed(2)} → '
                  '\$${alert.currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(changeIcon, color: changeColor),
              const SizedBox(height: 4),
              Text(
                '$sign${alert.percentageChange.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: changeColor,
                ),
              ),
              Text(
                '${alert.priceChange >= 0 ? '+' : ''}'
                '\$${alert.priceChange.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAlertsState extends StatelessWidget {
  const _EmptyAlertsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(Icons.notifications_none, size: 48, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'No Price Alerts Yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'SmartCart needs at least two recorded prices for a product before it can detect a meaningful change.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

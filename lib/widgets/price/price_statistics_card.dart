import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/price_history.dart';

class PriceStatisticsCard extends StatelessWidget {
  final PriceHistorySummary summary;

  const PriceStatisticsCard({
    super.key,
    required this.summary,
  });

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  IconData _trendIcon() {
    switch (summary.trend.toLowerCase()) {
      case 'rising':
        return Icons.trending_up;
      case 'falling':
        return Icons.trending_down;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.show_chart;
    }
  }

  Color _trendColor() {
  switch (summary.trend.toLowerCase()) {
    case 'rising':
      return Colors.red;
    case 'falling':
      return AppColors.success;
    case 'stable':
      return AppColors.warning;
    default:
      return Colors.grey;
  }
}

Color _changeColor() {
  if (summary.priceChange > 0) {
    return Colors.red;
  }

  if (summary.priceChange < 0) {
    return AppColors.success;
  }

  return AppColors.warning;
}

  Widget _priceTile({
    required String label,
    required double value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              _formatMoney(value),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: valueColor ?? AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 30,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.show_chart,
              size: 54,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            const Text(
              'No Price Intelligence Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a price or scan a receipt containing this product to begin building price intelligence.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) {
      return _emptyState();
    }

    final changePrefix = summary.priceChange > 0 ? '+' : '';
    final percentPrefix = summary.percentageChange > 0 ? '+' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Price Intelligence',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _priceTile(
                  label: 'Current',
                  value: summary.currentPrice,
                  icon: Icons.attach_money,
                ),
                const SizedBox(width: 10),
                _priceTile(
                  label: 'Average',
                  value: summary.averagePrice,
                  icon: Icons.calculate,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _priceTile(
                  label: 'Lowest',
                  value: summary.lowestPrice,
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(width: 10),
                _priceTile(
                  label: 'Highest',
                  value: summary.highestPrice,
                  icon: Icons.arrow_upward,
                ),
              ],
            ),
            const Divider(height: 30),
            _detailRow(
              icon: _trendIcon(),
              label: 'Trend',
              value: summary.trend,
              valueColor: _trendColor(),
            ),
            _detailRow(
              icon: Icons.swap_vert,
              label: 'Latest Change',
              value:
                  '$changePrefix${_formatMoney(summary.priceChange)} '
                  '($percentPrefix${summary.percentageChange.toStringAsFixed(1)}%)',
              valueColor: _changeColor(),
            ),
            _detailRow(
              icon: Icons.store,
              label: 'Best Recorded Store',
              value: summary.bestStore,
            ),
            _detailRow(
              icon: Icons.history,
              label: 'Most Recent Store',
              value: summary.mostRecentStore,
            ),
            _detailRow(
              icon: Icons.calendar_today,
              label: 'Last Updated',
              value: _formatDate(summary.lastUpdated),
            ),
            _detailRow(
              icon: Icons.format_list_numbered,
              label: 'Recorded Prices',
              value: summary.priceCount.toString(),
            ),
          ],
        ),
      ),
    );
  }
}
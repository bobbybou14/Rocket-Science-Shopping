import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/savings_summary.dart';
import '../store/store_badge.dart';

class SavingsSummaryCard extends StatelessWidget {
  final SavingsSummary summary;
  final bool isLoading;

  const SavingsSummaryCard({
    super.key,
    required this.summary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SavingsSummaryLoadingCard();
    }

    if (!summary.hasData) {
      return const _EmptySavingsSummaryCard();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.10), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(),
            const SizedBox(height: 20),
            _PotentialSavingsAmount(amount: summary.watchlistSavingsPotential),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.trending_down,
                    value: summary.priceDropCount.toString(),
                    label: summary.priceDropCount == 1
                        ? 'Price drop'
                        : 'Deals Found',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.compare_arrows,
                    value: summary.purchasesCompared.toString(),
                    label: summary.purchasesCompared == 1
                        ? 'Product compared'
                        : 'Items Tracked',
                  ),
                ),
              ],
            ),
            if (summary.bestDeal != null) ...[
              const SizedBox(height: 20),
              _BestOpportunityCard(highlight: summary.bestDeal!),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.savings_outlined,
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
                'Savings Opportunities',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'Helping you spend less on every grocery trip',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PotentialSavingsAmount extends StatelessWidget {
  final double amount;

  const _PotentialSavingsAmount({required this.amount});

  @override
  Widget build(BuildContext context) {
    final hasSavings = amount > 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: hasSavings
            ? Colors.green.withValues(alpha: 0.09)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSavings
              ? Colors.green.withValues(alpha: 0.22)
              : Colors.grey.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasSavings ? 'You could save' : 'Great news!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasSavings ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: hasSavings ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hasSavings
                ? "Based on the lowest prices we've found."
                : "You're already getting the best prices we've seen.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _BestOpportunityCard extends StatelessWidget {
  final SavingsHighlight highlight;

  const _BestOpportunityCard({required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 21,
                color: AppColors.primary,
              ),
              SizedBox(width: 7),
              Text(
                "Today's Best Deal",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            highlight.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 9),
          StoreBadge(storeName: highlight.storeName, compact: true),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _PriceLabel(label: 'Current', value: highlight.purchasePrice),
              _PriceLabel(label: 'Lowest', value: highlight.comparisonPrice),
              _PriceLabel(
                label: 'Save',
                value: highlight.amountSaved,
                emphasize: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasize;

  const _PriceLabel({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          TextSpan(
            text: '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: emphasize ? Colors.green.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySavingsSummaryCard extends StatelessWidget {
  const _EmptySavingsSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.savings_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'No Savings Opportunities Yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add products to your watchlist and record prices to compare current prices with their lowest recorded prices.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsSummaryLoadingCard extends StatelessWidget {
  const _SavingsSummaryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Finding savings opportunities...',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

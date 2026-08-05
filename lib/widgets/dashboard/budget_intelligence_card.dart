import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/budget_intelligence.dart';

class BudgetIntelligenceCard extends StatelessWidget {
  final BudgetIntelligence intelligence;

  const BudgetIntelligenceCard({super.key, required this.intelligence});

  @override
  Widget build(BuildContext context) {
    if (!intelligence.hasBudget) {
      return const _EmptyBudgetState();
    }

    final presentation = _statusPresentation(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(presentation),
            const SizedBox(height: 22),
            _buildBudgetSummary(context),
            const SizedBox(height: 20),
            _buildProgressSection(presentation),
            const SizedBox(height: 22),
            _buildProjectionCard(context, presentation),
            const SizedBox(height: 18),
            _buildInsight(context, presentation),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_BudgetStatusPresentation presentation) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: presentation.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: presentation.color,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget Intelligence',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'Your monthly grocery spending forecast',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: presentation.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(presentation.icon, color: presentation.color, size: 17),
              const SizedBox(width: 5),
              Text(
                presentation.label,
                style: TextStyle(
                  color: presentation.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 560;

          final metrics = [
            _BudgetMetric(
              label: 'Monthly Budget',
              value: _money(intelligence.monthlyBudget),
            ),
            _BudgetMetric(
              label: 'Spent',
              value: _money(intelligence.spentThisMonth),
            ),
            _BudgetMetric(
              label: intelligence.remainingBudget >= 0
                  ? 'Remaining'
                  : 'Over Budget',
              value: _money(intelligence.remainingBudget.abs()),
            ),
          ];

          if (isWide) {
            return Row(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: _BudgetMetricTile(metric: metrics[index])),
                ],
              ],
            );
          }

          return Column(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _BudgetMetricTile(metric: metrics[index]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressSection(_BudgetStatusPresentation presentation) {
    final displayedPercentage = intelligence.budgetUsedPercentage.clamp(
      0.0,
      999.0,
    );

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Budget Used',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${displayedPercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: presentation.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: LinearProgressIndicator(
            value: intelligence.progressValue,
            minHeight: 13,
            color: presentation.color,
            backgroundColor: presentation.color.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Text(
              '${intelligence.daysElapsed} days elapsed',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '${intelligence.daysRemaining} days remaining',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectionCard(
    BuildContext context,
    _BudgetStatusPresentation presentation,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: presentation.color.withValues(alpha: 0.16)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 560;

          final metrics = [
            _BudgetMetric(
              label: 'Projected Month-End',
              value: _money(intelligence.projectedMonthEndSpending),
            ),
            _BudgetMetric(
              label: 'Daily Spending Rate',
              value: _money(intelligence.dailySpendingRate),
            ),
            _BudgetMetric(
              label: 'Average Trip',
              value: _money(intelligence.averageTripCost),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_graph_outlined, color: presentation.color),
                  const SizedBox(width: 8),
                  const Text(
                    'Spending Forecast',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isWide)
                Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _ProjectionMetric(metric: metrics[index]),
                      ),
                    ],
                  ],
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: metrics.map((metric) {
                    return SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: _ProjectionMetric(metric: metric),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInsight(
    BuildContext context,
    _BudgetStatusPresentation presentation,
  ) {
    final insight = _buildInsightText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: presentation.color, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _buildInsightText() {
    if (!intelligence.hasSpendingData) {
      return 'Upload your first receipt this month to begin tracking your grocery budget.';
    }

    if (intelligence.isOverBudget) {
      return 'At your current spending pace, you are projected to exceed your monthly budget by about '
          '${_money(intelligence.projectedOverage)}.';
    }

    if (intelligence.needsAttention) {
      if (intelligence.projectedOverage > 0) {
        return 'Your current pace is slightly above target. Reducing upcoming spending by about '
            '${_money(intelligence.projectedOverage)} would keep you within budget.';
      }

      return 'Your spending is close to the recommended pace. Keep an eye on your next grocery trip.';
    }

    if (intelligence.projectedSavings > 0) {
      return 'Your current spending pace suggests you will finish about '
          '${_money(intelligence.projectedSavings)} under budget.';
    }

    if (intelligence.remainingBudget >= intelligence.averageTripCost &&
        intelligence.averageTripCost > 0) {
      return 'You can complete another average shopping trip and remain within your monthly budget.';
    }

    return 'Your grocery spending is currently tracking within your monthly budget.';
  }

  _BudgetStatusPresentation _statusPresentation(BuildContext context) {
    switch (intelligence.status) {
      case BudgetStatus.onTrack:
        return const _BudgetStatusPresentation(
          label: 'On Track',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        );

      case BudgetStatus.watch:
        return _BudgetStatusPresentation(
          label: 'Watch',
          icon: Icons.warning_amber_outlined,
          color: Colors.orange.shade700,
        );

      case BudgetStatus.overBudget:
        return _BudgetStatusPresentation(
          label: 'Over Budget',
          icon: Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }

  String _money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _BudgetStatusPresentation {
  final String label;
  final IconData icon;
  final Color color;

  const _BudgetStatusPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _BudgetMetric {
  final String label;
  final String value;

  const _BudgetMetric({required this.label, required this.value});
}

class _BudgetMetricTile extends StatelessWidget {
  final _BudgetMetric metric;

  const _BudgetMetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ProjectionMetric extends StatelessWidget {
  final _BudgetMetric metric;

  const _ProjectionMetric({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgetState extends StatelessWidget {
  const _EmptyBudgetState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Column(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 50,
              color: AppColors.primary,
            ),
            const SizedBox(height: 13),
            const Text(
              'No Grocery Budget Set',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a monthly budget to begin tracking your spending forecast.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

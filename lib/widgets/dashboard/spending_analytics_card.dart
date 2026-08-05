import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/spending_analytics.dart';

class SpendingAnalyticsCard extends StatefulWidget {
  final SpendingAnalytics analytics;
  final ValueChanged<MonthlySpendingPoint>? onViewMonth;

  const SpendingAnalyticsCard({
    super.key,
    required this.analytics,
    this.onViewMonth,
  });

  @override
  State<SpendingAnalyticsCard> createState() => _SpendingAnalyticsCardState();
}

class _SpendingAnalyticsCardState extends State<SpendingAnalyticsCard> {
  int? selectedMonthIndex;

  SpendingAnalytics get analytics => widget.analytics;

  @override
  void initState() {
    super.initState();
    _selectCurrentMonth();
  }

  @override
  void didUpdateWidget(covariant SpendingAnalyticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.analytics.monthlySpending !=
        widget.analytics.monthlySpending) {
      _selectCurrentMonth();
    }
  }

  void _selectCurrentMonth() {
    if (analytics.monthlySpending.isEmpty) {
      selectedMonthIndex = null;
      return;
    }

    selectedMonthIndex = analytics.monthlySpending.length - 1;
  }

  MonthlySpendingPoint? get selectedMonth {
    final index = selectedMonthIndex;

    if (index == null ||
        index < 0 ||
        index >= analytics.monthlySpending.length) {
      return null;
    }

    return analytics.monthlySpending[index];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: analytics.hasData
            ? _buildAnalytics(context)
            : const _EmptyAnalyticsState(),
      ),
    );
  }

  Widget _buildAnalytics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 22),
        _buildMonthlySummary(context),
        const SizedBox(height: 24),
        _buildMonthlyChart(context),
        if (selectedMonth != null) ...[
          const SizedBox(height: 18),
          _buildSelectedMonthDetails(context, selectedMonth!),
        ],
        const SizedBox(height: 26),
        _buildMetricGrid(),
        const SizedBox(height: 26),
        _buildTopStores(),
      ],
    );
  }

  Widget _buildHeader() {
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
            Icons.insights_outlined,
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
                'Spending Trends',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'Your grocery spending and shopping habits',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlySummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final changeColor = analytics.spendingDecreased
        ? AppColors.success
        : analytics.spendingIncreased
        ? colorScheme.error
        : Colors.grey.shade700;

    final changeIcon = analytics.spendingDecreased
        ? Icons.trending_down
        : analytics.spendingIncreased
        ? Icons.trending_up
        : Icons.trending_flat;

    String title;
    String changeMessage;

    if (!analytics.hasPreviousMonthData) {
      title = 'Building Your Trend';
      changeMessage = 'More history is needed for a monthly comparison';
    } else if (analytics.monthlyChangeAmount == 0) {
      title = 'Spending Unchanged';
      changeMessage = 'Your spending matches last month';
    } else if (analytics.spendingDecreased) {
      title = 'Great Job!';
      changeMessage =
          '${_money(analytics.monthlyChangeAmount.abs())} less than last month · '
          '${analytics.monthlyChangePercentage.abs().toStringAsFixed(1)}% decrease';
    } else {
      title = 'Spending Increased';
      changeMessage =
          '${_money(analytics.monthlyChangeAmount.abs())} more than last month · '
          '${analytics.monthlyChangePercentage.abs().toStringAsFixed(1)}% increase';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Month',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.75,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(analytics.currentMonthSpending),
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  changeMessage,
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(changeIcon, color: changeColor, size: 42),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(BuildContext context) {
    final points = analytics.monthlySpending;

    double highestValue = 0;

    for (final point in points) {
      if (point.totalSpent > highestValue) {
        highestValue = point.totalSpent;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Last Six Months',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              'Tap a month',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < points.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MonthlyBar(
                    point: points[index],
                    highestValue: highestValue,
                    isCurrentMonth: index == points.length - 1,
                    isSelected: index == selectedMonthIndex,
                    onTap: () {
                      setState(() {
                        selectedMonthIndex = index;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMonthDetails(
    BuildContext context,
    MonthlySpendingPoint point,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('${point.year}-${point.month}'),
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    point.fullMonthLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onViewMonth != null)
                  TextButton.icon(
                    onPressed: () {
                      widget.onViewMonth?.call(point);
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View Trips'),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 4 : 2;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 10)) / columns;

                final details = [
                  _MonthDetail(
                    label: 'Total Spent',
                    value: _money(point.totalSpent),
                  ),
                  _MonthDetail(label: 'Trips', value: '${point.tripCount}'),
                  _MonthDetail(
                    label: 'Average Trip',
                    value: _money(point.averageTripCost),
                  ),
                  _MonthDetail(
                    label: 'Largest Trip',
                    value: _money(point.largestTrip),
                  ),
                  _MonthDetail(
                    label: 'Smallest Trip',
                    value: _money(point.smallestTrip),
                  ),
                ];

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: details.map((detail) {
                    return SizedBox(
                      width: width,
                      child: _MonthDetailTile(detail: detail),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid() {
    final metrics = [
      _AnalyticsMetric(
        icon: Icons.receipt_long_outlined,
        label: 'Average Trip',
        value: _money(analytics.averageTripCost),
      ),
      _AnalyticsMetric(
        icon: Icons.calendar_today_outlined,
        label: 'Common Day',
        value: analytics.mostCommonShoppingDay,
      ),
      _AnalyticsMetric(
        icon: Icons.arrow_upward,
        label: 'Largest Trip',
        value: _money(analytics.largestTrip),
      ),
      _AnalyticsMetric(
        icon: Icons.arrow_downward,
        label: 'Smallest Trip',
        value: _money(analytics.smallestTrip),
      ),
      _AnalyticsMetric(
        icon: Icons.schedule_outlined,
        label: 'Between Trips',
        value: analytics.averageDaysBetweenTrips <= 0
            ? 'Not enough data'
            : '${analytics.averageDaysBetweenTrips.toStringAsFixed(1)} days',
      ),
      _AnalyticsMetric(
        icon: Icons.shopping_bag_outlined,
        label: 'Trips Analyzed',
        value: '${analytics.totalTrips}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics.map((metric) {
            return SizedBox(
              width: itemWidth,
              child: _MetricTile(metric: metric),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTopStores() {
    if (analytics.topStores.isEmpty) {
      return const SizedBox.shrink();
    }

    final highestSpending = analytics.topStores.first.totalSpent;

    final totalStoreSpending = analytics.topStores.fold<double>(
      0,
      (total, store) => total + store.totalSpent,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Stores by Spending',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        ...analytics.topStores.map((store) {
          final progress = highestSpending <= 0
              ? 0.0
              : store.totalSpent / highestSpending;

          final percentage = totalStoreSpending <= 0
              ? 0.0
              : (store.totalSpent / totalStoreSpending) * 100;

          return Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _money(store.totalSpent),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}% of displayed store spending',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${store.tripCount} '
                      '${store.tripCount == 1 ? 'trip' : 'trips'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _MonthlyBar extends StatefulWidget {
  final MonthlySpendingPoint point;
  final double highestValue;
  final bool isCurrentMonth;
  final bool isSelected;
  final VoidCallback onTap;

  const _MonthlyBar({
    required this.point,
    required this.highestValue,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MonthlyBar> createState() => _MonthlyBarState();
}

class _MonthlyBarState extends State<_MonthlyBar> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final ratio = widget.highestValue <= 0
        ? 0.0
        : widget.point.totalSpent / widget.highestValue;

    final baseHeight = widget.point.totalSpent <= 0
        ? 5.0
        : 25 + (105 * ratio.clamp(0.0, 1.0));

    final highlighted = widget.isSelected || isHovered;

    final barHeight = highlighted ? baseHeight + 9 : baseHeight;

    final barColor = widget.isSelected
        ? colorScheme.primary
        : widget.isCurrentMonth
        ? colorScheme.primary.withValues(alpha: 0.78)
        : colorScheme.primary.withValues(alpha: isHovered ? 0.58 : 0.38);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              widget.point.totalSpent <= 0
                  ? '\$0'
                  : '\$${widget.point.totalSpent.toStringAsFixed(0)}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: highlighted ? FontWeight.bold : FontWeight.w600,
                color: highlighted ? colorScheme.primary : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                border: widget.isSelected
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.point.monthLabel,
              style: TextStyle(
                fontSize: 12,
                color: widget.isSelected ? colorScheme.primary : null,
                fontWeight: highlighted ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthDetail {
  final String label;
  final String value;

  const _MonthDetail({required this.label, required this.value});
}

class _MonthDetailTile extends StatelessWidget {
  final _MonthDetail detail;

  const _MonthDetailTile({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 73),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            detail.label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMetric {
  final IconData icon;
  final String label;
  final String value;

  const _AnalyticsMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _MetricTile extends StatelessWidget {
  final _AnalyticsMetric metric;

  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: AppColors.primary, size: 23),
          const SizedBox(height: 10),
          Text(
            metric.value,
            maxLines: 2,
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

class _EmptyAnalyticsState extends StatelessWidget {
  const _EmptyAnalyticsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.insights_outlined, size: 50, color: AppColors.primary),
          SizedBox(height: 13),
          Text(
            'No Spending Analytics Yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Upload grocery receipts to begin tracking spending trends and shopping habits.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

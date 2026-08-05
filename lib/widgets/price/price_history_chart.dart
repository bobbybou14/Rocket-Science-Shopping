import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/price_history.dart';

class PriceHistoryChart extends StatelessWidget {
  final List<PriceHistoryEntry> entries;

  const PriceHistoryChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = [...entries]
      ..sort((first, second) {
        return first.createdAt.compareTo(second.createdAt);
      });

    if (sortedEntries.length < 2) {
      return _buildInsufficientDataCard(sortedEntries);
    }

    final prices = sortedEntries.map((entry) => entry.price).toList();

    final lowestPrice = prices.reduce(math.min);
    final highestPrice = prices.reduce(math.max);
    final averagePrice =
        prices.fold<double>(0, (sum, price) => sum + price) / prices.length;

    final firstPrice = sortedEntries.first.price;
    final latestPrice = sortedEntries.last.price;
    final priceDifference = latestPrice - firstPrice;

    final percentageChange = firstPrice == 0
        ? 0.0
        : (priceDifference / firstPrice) * 100;

    final trend = _PriceTrend.fromDifference(priceDifference);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.show_chart, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text(
                            'Price Trend',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _TrendBadge(trend: trend, percentageChange: percentageChange),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${sortedEntries.length} recorded price'
              '${sortedEntries.length == 1 ? '' : 's'} from '
              '${_formatDisplayDate(sortedEntries.first.createdAt)} to '
              '${_formatDisplayDate(sortedEntries.last.createdAt)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Container(
              height: 260,
              padding: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
              child: CustomPaint(
                painter: _PriceHistoryChartPainter(
                  entries: sortedEntries,
                  lowestPrice: lowestPrice,
                  highestPrice: highestPrice,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Lowest',
                    amount: lowestPrice,
                    icon: Icons.south,
                    emphasized: lowestPrice == latestPrice,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Average',
                    amount: averagePrice,
                    icon: Icons.horizontal_rule,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Highest',
                    amount: highestPrice,
                    icon: Icons.north,
                    emphasized: highestPrice == latestPrice,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: trend.backgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(trend.icon, color: trend.foregroundColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _buildTrendDescription(
                        trend: trend,
                        difference: priceDifference,
                        firstPrice: firstPrice,
                        latestPrice: latestPrice,
                      ),
                      style: TextStyle(
                        color: trend.foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsufficientDataCard(List<PriceHistoryEntry> sortedEntries) {
    final hasOneEntry = sortedEntries.length == 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.show_chart,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Not Enough Data for a Chart',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasOneEntry
                  ? 'One price has been recorded. Add one more price to '
                        'begin displaying a trend.'
                  : 'At least two recorded prices are needed to display '
                        'a price trend.',
              textAlign: TextAlign.center,
            ),
            if (hasOneEntry) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Current recorded price',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${sortedEntries.first.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDisplayDate(sortedEntries.first.createdAt),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildTrendDescription({
    required _PriceTrend trend,
    required double difference,
    required double firstPrice,
    required double latestPrice,
  }) {
    final absoluteDifference = difference.abs();

    switch (trend) {
      case _PriceTrend.decreased:
        return 'The latest price is '
            '\$${absoluteDifference.toStringAsFixed(2)} lower than the '
            'first recorded price of \$${firstPrice.toStringAsFixed(2)}.';

      case _PriceTrend.increased:
        return 'The latest price is '
            '\$${absoluteDifference.toStringAsFixed(2)} higher than the '
            'first recorded price of \$${firstPrice.toStringAsFixed(2)}.';

      case _PriceTrend.unchanged:
        return 'The price has remained at '
            '\$${latestPrice.toStringAsFixed(2)} since the first record.';
    }
  }

  static String _formatDisplayDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final bool emphasized;

  const _MetricTile({
    required this.label,
    required this.amount,
    required this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasized
              ? AppColors.primary.withValues(alpha: 0.30)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final _PriceTrend trend;
  final double percentageChange;

  const _TrendBadge({required this.trend, required this.percentageChange});

  @override
  Widget build(BuildContext context) {
    final percentageText = percentageChange.abs().toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: trend.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trend.icon, size: 17, color: trend.foregroundColor),
          const SizedBox(width: 5),
          Text(
            trend == _PriceTrend.unchanged ? 'No change' : '$percentageText%',
            style: TextStyle(
              color: trend.foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PriceTrend {
  decreased,
  increased,
  unchanged;

  static _PriceTrend fromDifference(double difference) {
    if (difference < -0.005) {
      return _PriceTrend.decreased;
    }

    if (difference > 0.005) {
      return _PriceTrend.increased;
    }

    return _PriceTrend.unchanged;
  }

  IconData get icon {
    switch (this) {
      case _PriceTrend.decreased:
        return Icons.trending_down;

      case _PriceTrend.increased:
        return Icons.trending_up;

      case _PriceTrend.unchanged:
        return Icons.trending_flat;
    }
  }

  Color get foregroundColor {
    switch (this) {
      case _PriceTrend.decreased:
        return AppColors.success;

      case _PriceTrend.increased:
        return AppColors.primary;

      case _PriceTrend.unchanged:
        return Colors.blueGrey;
    }
  }

  Color get backgroundColor {
    return foregroundColor.withValues(alpha: 0.11);
  }
}

class _PriceHistoryChartPainter extends CustomPainter {
  final List<PriceHistoryEntry> entries;
  final double lowestPrice;
  final double highestPrice;

  const _PriceHistoryChartPainter({
    required this.entries,
    required this.lowestPrice,
    required this.highestPrice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) {
      return;
    }

    const leftPadding = 54.0;
    const rightPadding = 18.0;
    const topPadding = 20.0;
    const bottomPadding = 42.0;

    final chartWidth = math.max(1.0, size.width - leftPadding - rightPadding);

    final chartHeight = math.max(1.0, size.height - topPadding - bottomPadding);

    final rawRange = highestPrice - lowestPrice;

    final verticalBuffer = rawRange.abs() < 0.01
        ? math.max(0.25, highestPrice * 0.08)
        : rawRange * 0.14;

    final minimumDisplayPrice = math.max(0.0, lowestPrice - verticalBuffer);

    final maximumDisplayPrice = highestPrice + verticalBuffer;

    final displayRange = math.max(
      0.01,
      maximumDisplayPrice - minimumDisplayPrice,
    );

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.20)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.65)
      ..strokeWidth = 1.2;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.22),
              AppColors.primary.withValues(alpha: 0.015),
            ],
          ).createShader(
            Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
          )
      ..style = PaintingStyle.fill;

    const horizontalLineCount = 4;

    for (int index = 0; index <= horizontalLineCount; index++) {
      final progress = index / horizontalLineCount;
      final y = topPadding + (chartHeight * progress);

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final priceValue = maximumDisplayPrice - (displayRange * progress);

      _drawText(
        canvas,
        '\$${priceValue.toStringAsFixed(2)}',
        Offset(0, y - 8),
        const TextStyle(fontSize: 10.5, color: Colors.grey),
        maxWidth: leftPadding - 7,
        textAlign: TextAlign.right,
      );
    }

    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );

    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(leftPadding + chartWidth, topPadding + chartHeight),
      axisPaint,
    );

    final firstDate = entries.first.createdAt;
    final lastDate = entries.last.createdAt;

    final totalMilliseconds = lastDate.difference(firstDate).inMilliseconds;

    final points = <Offset>[];

    for (int index = 0; index < entries.length; index++) {
      final entry = entries[index];

      final double horizontalProgress;

      if (totalMilliseconds == 0) {
        horizontalProgress = entries.length == 1
            ? 0
            : index / (entries.length - 1);
      } else {
        final elapsedMilliseconds = entry.createdAt
            .difference(firstDate)
            .inMilliseconds;

        horizontalProgress = elapsedMilliseconds / totalMilliseconds;
      }

      final x = leftPadding + chartWidth * horizontalProgress;

      final normalizedPrice =
          (entry.price - minimumDisplayPrice) / displayRange;

      final y = topPadding + chartHeight - (normalizedPrice * chartHeight);

      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (int index = 1; index < points.length; index++) {
      linePath.lineTo(points[index].dx, points[index].dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, topPadding + chartHeight)
      ..lineTo(points.first.dx, topPadding + chartHeight)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    for (int index = 0; index < points.length; index++) {
      final point = points[index];
      final entry = entries[index];

      final isLowest = (entry.price - lowestPrice).abs() < 0.005;

      final isHighest = (entry.price - highestPrice).abs() < 0.005;

      final pointColor = isLowest
          ? AppColors.success
          : isHighest
          ? AppColors.primary
          : AppColors.primary;

      canvas.drawCircle(
        point,
        8,
        Paint()
          ..color = pointColor.withValues(alpha: 0.17)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        point,
        4.5,
        Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        point,
        2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }

    final middleIndex = entries.length ~/ 2;

    _drawDateLabel(
      canvas,
      entries.first.createdAt,
      Offset(leftPadding, topPadding + chartHeight + 10),
      chartWidth / 3,
      TextAlign.left,
    );

    if (entries.length >= 4) {
      _drawDateLabel(
        canvas,
        entries[middleIndex].createdAt,
        Offset(leftPadding + chartWidth / 3, topPadding + chartHeight + 10),
        chartWidth / 3,
        TextAlign.center,
      );
    }

    _drawDateLabel(
      canvas,
      entries.last.createdAt,
      Offset(leftPadding + (chartWidth * 2 / 3), topPadding + chartHeight + 10),
      chartWidth / 3,
      TextAlign.right,
    );
  }

  void _drawDateLabel(
    Canvas canvas,
    DateTime date,
    Offset offset,
    double maxWidth,
    TextAlign alignment,
  ) {
    _drawText(
      canvas,
      _formatChartDate(date),
      offset,
      const TextStyle(fontSize: 10.5, color: Colors.grey),
      maxWidth: maxWidth,
      textAlign: alignment,
    );
  }

  String _formatChartDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}';
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: '…',
    );

    painter.layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PriceHistoryChartPainter oldDelegate) {
    if (oldDelegate.entries.length != entries.length) {
      return true;
    }

    for (int index = 0; index < entries.length; index++) {
      final current = entries[index];
      final previous = oldDelegate.entries[index];

      if (current.price != previous.price ||
          current.createdAt != previous.createdAt) {
        return true;
      }
    }

    return oldDelegate.lowestPrice != lowestPrice ||
        oldDelegate.highestPrice != highestPrice;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/price_history.dart';

class PriceHistoryChart extends StatelessWidget {
  final List<PriceHistoryEntry> entries;

  const PriceHistoryChart({
    super.key,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 30,
          ),
          child: Column(
            children: const [
              Icon(
                Icons.show_chart,
                size: 54,
                color: AppColors.primary,
              ),
              SizedBox(height: 14),
              Text(
                'Not Enough Data for a Chart',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'At least two recorded prices are needed to display a price trend.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final sortedEntries = [...entries]
      ..sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.show_chart,
                  color: AppColors.primary,
                ),
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
            const SizedBox(height: 6),
            Text(
              '${sortedEntries.length} recorded price'
              '${sortedEntries.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 230,
              child: CustomPaint(
                painter: _PriceHistoryChartPainter(
                  entries: sortedEntries,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _legendItem(
                    label: 'First',
                    value: sortedEntries.first.price,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _legendItem(
                    label: 'Latest',
                    value: sortedEntries.last.price,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem({
    required String label,
    required double value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceHistoryChartPainter extends CustomPainter {
  final List<PriceHistoryEntry> entries;

  const _PriceHistoryChartPainter({
    required this.entries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;

    const leftPadding = 48.0;
    const rightPadding = 16.0;
    const topPadding = 16.0;
    const bottomPadding = 34.0;

    final chartWidth =
        math.max(1.0, size.width - leftPadding - rightPadding);
    final chartHeight =
        math.max(1.0, size.height - topPadding - bottomPadding);

    final prices = entries.map((entry) => entry.price).toList();

    double minPrice = prices.reduce(math.min);
    double maxPrice = prices.reduce(math.max);

    if ((maxPrice - minPrice).abs() < 0.01) {
      minPrice -= 0.50;
      maxPrice += 0.50;
    }

    final priceRange = maxPrice - minPrice;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.2;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    const horizontalLines = 4;

    for (int index = 0; index <= horizontalLines; index++) {
      final y =
          topPadding + (chartHeight / horizontalLines) * index;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final priceValue =
          maxPrice - (priceRange / horizontalLines) * index;

      _drawText(
        canvas,
        '\$${priceValue.toStringAsFixed(2)}',
        Offset(0, y - 8),
        const TextStyle(
          fontSize: 11,
          color: Colors.grey,
        ),
        maxWidth: leftPadding - 6,
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

    final totalMilliseconds =
        lastDate.difference(firstDate).inMilliseconds;

    final points = <Offset>[];

    for (final entry in entries) {
      final elapsedMilliseconds =
          entry.createdAt.difference(firstDate).inMilliseconds;

      final timeProgress = totalMilliseconds == 0
          ? 0.0
          : elapsedMilliseconds / totalMilliseconds;

      final x = leftPadding + chartWidth * timeProgress;

      final normalizedPrice =
          (entry.price - minPrice) / priceRange;

      final y = topPadding +
          chartHeight -
          (normalizedPrice * chartHeight);

      points.add(Offset(x, y));
    }

    final path = Path()
      ..moveTo(points.first.dx, points.first.dy);

    for (int index = 1; index < points.length; index++) {
      path.lineTo(points[index].dx, points[index].dy);
    }

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4.5, pointPaint);
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
    }

    _drawText(
      canvas,
      _formatDate(entries.first.createdAt),
      Offset(leftPadding, topPadding + chartHeight + 8),
      const TextStyle(
        fontSize: 11,
        color: Colors.grey,
      ),
      maxWidth: chartWidth / 2,
      textAlign: TextAlign.left,
    );

    _drawText(
      canvas,
      _formatDate(entries.last.createdAt),
      Offset(
        leftPadding + chartWidth / 2,
        topPadding + chartHeight + 8,
      ),
      const TextStyle(
        fontSize: 11,
        color: Colors.grey,
      ),
      maxWidth: chartWidth / 2,
      textAlign: TextAlign.right,
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$month-$day';
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
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );

    painter.layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(
    covariant _PriceHistoryChartPainter oldDelegate,
  ) {
    return oldDelegate.entries != entries;
  }
}
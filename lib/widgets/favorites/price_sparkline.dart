import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/price_history.dart';

class PriceSparkline extends StatelessWidget {
  final List<PriceHistoryEntry> entries;
  final double height;
  final double width;

  const PriceSparkline({
    super.key,
    required this.entries,
    this.height = 48,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final sortedEntries = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (sortedEntries.length < 2) {
      return SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: Text(
            'Not enough price data',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    final firstPrice = sortedEntries.first.price;
    final lastPrice = sortedEntries.last.price;

    final Color lineColor;

    if (lastPrice < firstPrice) {
      lineColor = Colors.green;
    } else if (lastPrice > firstPrice) {
      lineColor = Colors.red;
    } else {
      lineColor = Colors.blue;
    }

    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _PriceSparklinePainter(
          entries: sortedEntries,
          lineColor: lineColor,
        ),
      ),
    );
  }
}

class _PriceSparklinePainter extends CustomPainter {
  final List<PriceHistoryEntry> entries;
  final Color lineColor;

  const _PriceSparklinePainter({
    required this.entries,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) {
      return;
    }

    final prices = entries.map((entry) => entry.price).toList();

    final minimumPrice = prices.reduce(math.min);
    final maximumPrice = prices.reduce(math.max);

    final priceRange = maximumPrice - minimumPrice;

    const horizontalPadding = 4.0;
    const verticalPadding = 5.0;

    final chartWidth = size.width - (horizontalPadding * 2);

    final chartHeight = size.height - (verticalPadding * 2);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final points = <Offset>[];

    for (int index = 0; index < entries.length; index++) {
      final x = horizontalPadding + (chartWidth * index / (entries.length - 1));

      final normalizedPrice = priceRange == 0
          ? 0.5
          : (entries[index].price - minimumPrice) / priceRange;

      final y = verticalPadding + chartHeight - (normalizedPrice * chartHeight);

      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (int index = 1; index < points.length; index++) {
      linePath.lineTo(points[index].dx, points[index].dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height - verticalPadding)
      ..lineTo(points.first.dx, size.height - verticalPadding)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    canvas.drawCircle(points.last, 3.5, pointPaint);

    canvas.drawCircle(
      points.last,
      1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PriceSparklinePainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.lineColor != lineColor;
  }
}

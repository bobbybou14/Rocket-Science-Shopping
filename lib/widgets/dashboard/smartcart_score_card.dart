import 'package:flutter/material.dart';

import '../../models/smartcart_score.dart';

class SmartCartScoreCard extends StatelessWidget {
  final SmartCartScore score;

  const SmartCartScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scoreColor = _scoreColor(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scoreColor.withValues(alpha: 0.16), colorScheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 650;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ScoreIndicator(score: score, color: scoreColor),
                  const SizedBox(width: 28),
                  Expanded(
                    child: _ScoreDetails(score: score, color: scoreColor),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _ScoreIndicator(score: score, color: scoreColor),
                const SizedBox(height: 22),
                _ScoreDetails(score: score, color: scoreColor),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _scoreColor(BuildContext context) {
    if (score.score >= 85) {
      return Colors.green;
    }

    if (score.score >= 70) {
      return Colors.teal;
    }

    if (score.score >= 55) {
      return Colors.orange;
    }

    if (score.score >= 30) {
      return Colors.deepOrange;
    }

    return Theme.of(context).colorScheme.primary;
  }
}

class _ScoreIndicator extends StatelessWidget {
  final SmartCartScore score;
  final Color color;

  const _ScoreIndicator({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      height: 172,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: score.progress,
              strokeWidth: 13,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.score.toString(),
                style: TextStyle(
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'OUT OF 100',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  score.grade,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreDetails extends StatelessWidget {
  final SmartCartScore score;
  final Color color;

  const _ScoreDetails({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome),
            SizedBox(width: 8),
            Text(
              'SMARTCART SCORE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          score.title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 7),
        Text(
          score.summary,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 20),
        _MetricsGrid(score: score),
        const SizedBox(height: 20),
        _ScoreBreakdown(score: score, color: color),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final SmartCartScore score;

  const _MetricsGrid({required this.score});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricChip(
          icon: Icons.receipt_long_outlined,
          value: score.totalTrips.toString(),
          label: score.totalTrips == 1 ? 'Trip' : 'Trips',
        ),
        _MetricChip(
          icon: Icons.store_outlined,
          value: score.storesVisited.toString(),
          label: score.storesVisited == 1 ? 'Store' : 'Stores',
        ),
        _MetricChip(
          icon: Icons.compare_arrows,
          value: score.productsCompared.toString(),
          label: 'Compared',
        ),
        _MetricChip(
          icon: Icons.trending_down,
          value: score.priceDropCount.toString(),
          label: score.priceDropCount == 1 ? 'Price drop' : 'Price drops',
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 7),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  final SmartCartScore score;
  final Color color;

  const _ScoreBreakdown({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: const Text(
        'How your score is calculated',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        _BreakdownRow(
          label: 'Shopping history',
          points: score.historyPoints,
          maximum: 25,
          color: color,
        ),
        _BreakdownRow(
          label: 'Recent activity',
          points: score.activityPoints,
          maximum: 15,
          color: color,
        ),
        _BreakdownRow(
          label: 'Price coverage',
          points: score.priceCoveragePoints,
          maximum: 20,
          color: color,
        ),
        _BreakdownRow(
          label: 'Verified data',
          points: score.dataQualityPoints,
          maximum: 20,
          color: color,
        ),
        _BreakdownRow(
          label: 'Price opportunities',
          points: score.opportunityPoints,
          maximum: 20,
          color: color,
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int points;
  final int maximum;
  final Color color;

  const _BreakdownRow({
    required this.label,
    required this.points,
    required this.maximum,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label)),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: maximum == 0 ? 0 : points / maximum,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              '$points/$maximum',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class WatchlistEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const WatchlistEmptyState({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.star_border, size: 90, color: AppColors.primary),
          SizedBox(height: 18),
          Text(
            'No Favourite Products Yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Browse products and tap the star to build your watchlist. Once you start tracking products, SmartCart will show price trends and shopping insights here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );
  }
}

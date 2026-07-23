import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum WatchlistSort {
  biggestDrop,
  biggestIncrease,
  lowestCurrentPrice,
  recentlyUpdated,
  productName,
}

class WatchlistSortBar extends StatelessWidget {
  final WatchlistSort selectedSort;
  final ValueChanged<WatchlistSort> onChanged;

  const WatchlistSortBar({
    super.key,
    required this.selectedSort,
    required this.onChanged,
  });

  String labelForSort(WatchlistSort sort) {
    switch (sort) {
      case WatchlistSort.biggestDrop:
        return 'Biggest Price Drop';
      case WatchlistSort.biggestIncrease:
        return 'Biggest Price Increase';
      case WatchlistSort.lowestCurrentPrice:
        return 'Lowest Current Price';
      case WatchlistSort.recentlyUpdated:
        return 'Recently Updated';
      case WatchlistSort.productName:
        return 'Product Name';
    }
  }

  IconData iconForSort(WatchlistSort sort) {
    switch (sort) {
      case WatchlistSort.biggestDrop:
        return Icons.trending_down;
      case WatchlistSort.biggestIncrease:
        return Icons.trending_up;
      case WatchlistSort.lowestCurrentPrice:
        return Icons.attach_money;
      case WatchlistSort.recentlyUpdated:
        return Icons.schedule;
      case WatchlistSort.productName:
        return Icons.sort_by_alpha;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<WatchlistSort>(
            value: selectedSort,
            isExpanded: true,
            icon: const Icon(Icons.expand_more),
            items: WatchlistSort.values.map((sort) {
              return DropdownMenuItem<WatchlistSort>(
                value: sort,
                child: Row(
                  children: [
                    Icon(iconForSort(sort), size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        labelForSort(sort),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (sort) {
              if (sort != null) {
                onChanged(sort);
              }
            },
          ),
        ),
      ),
    );
  }
}

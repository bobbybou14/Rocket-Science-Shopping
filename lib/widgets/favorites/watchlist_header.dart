import 'package:flutter/material.dart';

class WatchlistHeader extends StatelessWidget {
  final int totalProducts;

  const WatchlistHeader({super.key, required this.totalProducts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Watchlist',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '$totalProducts favourite product'
          '${totalProducts == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }
}

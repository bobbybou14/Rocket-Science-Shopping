import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/store_branding.dart';
import '../../models/price_history.dart';

class PriceHistoryList extends StatelessWidget {
  final List<PriceHistoryEntry> entries;

  const PriceHistoryList({super.key, required this.entries});

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
          child: Column(
            children: const [
              Icon(Icons.receipt_long, size: 54, color: AppColors.primary),
              SizedBox(height: 14),
              Text(
                'No Price History',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Start scanning receipts or adding prices to build your history.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Price History',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        ...entries.reversed.map((entry) {
          final branding = StoreBranding.fromStoreName(entry.store);

          final location = [
            entry.city,
            entry.province,
          ].where((e) => e.trim().isNotEmpty).join(', ');

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: branding.backgroundColor,
                child: Icon(branding.icon, color: branding.primaryColor),
              ),
              title: Text(
                branding.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: branding.primaryColor,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDate(entry.createdAt)),
                  if (location.isNotEmpty) Text(location),
                  if (entry.source.trim().isNotEmpty)
                    Text('Source: ${entry.source}'),
                ],
              ),
              trailing: Text(
                '\$${entry.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

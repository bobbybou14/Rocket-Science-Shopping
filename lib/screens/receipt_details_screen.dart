import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/receipt.dart';
import 'receipt_items_screen.dart';

class ReceiptDetailsScreen extends StatelessWidget {
  final Receipt receipt;

  const ReceiptDetailsScreen({super.key, required this.receipt});

  String formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  void openReceiptItems(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptItemsScreen(receipt: receipt)),
    );
  }

  Widget infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }

  Widget statusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Processing Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Status: ${receipt.processingStatus}'),
            Text(
              'Personal data redacted: ${receipt.personalDataRedacted ? "Yes" : "No"}',
            ),
            Text('Raw image stored: ${receipt.rawImageStored ? "Yes" : "No"}'),
          ],
        ),
      ),
    );
  }

  Widget privacyCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Privacy Protection\n\n'
          'SmartCart is currently saving only cleaned receipt metadata. '
          'The original receipt image is not stored at this stage.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeName = receipt.storeName.isEmpty
        ? 'Unknown Store'
        : receipt.storeName;

    final location = [
      receipt.city,
      receipt.province,
    ].where((item) => item.isNotEmpty).join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.receipt_long, size: 90, color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            storeName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          if (location.isNotEmpty)
            Text(
              location,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          const SizedBox(height: 25),
          infoCard(icon: Icons.store, title: 'Store', value: storeName),
          infoCard(
            icon: Icons.location_on,
            title: 'Location',
            value: location.isEmpty ? 'Unknown location' : location,
          ),
          infoCard(
            icon: Icons.calendar_today,
            title: 'Purchase Date',
            value: formatDate(receipt.purchaseDate),
          ),
          infoCard(
            icon: Icons.attach_money,
            title: 'Receipt Total',
            value: receipt.total == 0
                ? 'Not captured yet'
                : '\$${receipt.total.toStringAsFixed(2)}',
          ),
          statusCard(),
          privacyCard(),
          if (receipt.notes.isNotEmpty)
            infoCard(icon: Icons.notes, title: 'Notes', value: receipt.notes),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => openReceiptItems(context),
            icon: const Icon(Icons.list_alt),
            label: const Text('View Receipt Items'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete receipt coming soon.')),
              );
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Receipt'),
          ),
        ],
      ),
    );
  }
}

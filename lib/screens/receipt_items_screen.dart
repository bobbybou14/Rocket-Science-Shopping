import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../service/receipt_service.dart';
import 'receipt_upload_screen.dart';

class ReceiptItemsScreen extends StatefulWidget {
  final Receipt receipt;

  const ReceiptItemsScreen({super.key, required this.receipt});

  @override
  State<ReceiptItemsScreen> createState() => _ReceiptItemsScreenState();
}

class _ReceiptItemsScreenState extends State<ReceiptItemsScreen> {
  List<ReceiptItem> items = [];

  bool isLoading = true;
  String? errorMessage;

  Receipt get receipt => widget.receipt;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedItems = await ReceiptService.getReceiptItems(receipt.id);

      if (!mounted) return;

      setState(() {
        items = loadedItems;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error.toString();
      });
    }
  }

  void openReceiptUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptUploadScreen()),
    );
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toStringAsFixed(2);
  }

  double get calculatedTotal {
    return items.fold<double>(0, (total, item) => total + item.totalPrice);
  }

  int get matchedCount {
    return items.where((item) => item.matchedProduct).length;
  }

  int get reviewCount {
    return items.where((item) {
      return !item.matchedProduct || item.confidenceScore < 75;
    }).length;
  }

  Widget buildReceiptSummary() {
    final storeName = receipt.storeName.trim().isEmpty
        ? 'Unknown Store'
        : receipt.storeName;

    final location = [
      receipt.city,
      receipt.province,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: AppColors.primary,
                  size: 42,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(location),
                      ],
                      const SizedBox(height: 4),
                      Text(formatDate(receipt.purchaseDate)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _summaryValue(label: 'Items', value: items.length.toString()),
                _summaryValue(label: 'Matched', value: matchedCount.toString()),
                _summaryValue(label: 'Review', value: reviewCount.toString()),
                _summaryValue(
                  label: 'Total',
                  value: '\$${receipt.total.toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryValue({required String label, required String value}) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget buildItemCard(ReceiptItem item) {
    final requiresReview = !item.matchedProduct || item.confidenceScore < 75;

    final confidence = item.confidenceScore.clamp(0, 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: requiresReview
                    ? Colors.orange.withValues(alpha: 0.12)
                    : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                requiresReview ? Icons.priority_high : Icons.check,
                color: requiresReview
                    ? Colors.orange.shade800
                    : Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName.trim().isEmpty
                        ? 'Unknown Product'
                        : item.productName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Quantity: ${formatQuantity(item.quantity)}'
                    '  •  Unit: \$${item.unitPrice.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.matchedProduct
                        ? 'Matched product • $confidence% confidence'
                        : 'Product match requires review',
                    style: TextStyle(
                      color: requiresReview
                          ? Colors.orange.shade900
                          : Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.barcode != null &&
                      item.barcode!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Barcode: ${item.barcode}'),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '\$${item.totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildItemsList() {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 54,
                color: AppColors.primary,
              ),
              const SizedBox(height: 14),
              const Text(
                'Receipt items could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: loadItems,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 18),
              const Text(
                'No receipt items found.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'This receipt does not have any saved item records. '
                'Try refreshing, or process the receipt again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: loadItems,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Receipt Items (${items.length})',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.map(buildItemCard),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _totalRow(
                  label: 'Calculated item total',
                  amount: calculatedTotal,
                ),
                if (receipt.subtotal > 0)
                  _totalRow(label: 'Subtotal', amount: receipt.subtotal),
                if (receipt.tax > 0)
                  _totalRow(label: 'Tax', amount: receipt.tax),
                const Divider(height: 24),
                _totalRow(
                  label: 'Receipt total',
                  amount: receipt.total,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalRow({
    required String label,
    required double amount,
    bool emphasized = false,
  }) {
    final style = TextStyle(
      fontSize: emphasized ? 19 : 16,
      fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('\$${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Items'),
        actions: [
          IconButton(
            onPressed: loadItems,
            tooltip: 'Refresh items',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadItems,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            buildReceiptSummary(),
            const SizedBox(height: 18),
            buildItemsList(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: openReceiptUpload,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Upload Another Receipt'),
            ),
          ],
        ),
      ),
    );
  }
}

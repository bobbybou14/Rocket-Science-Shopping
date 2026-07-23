import 'package:flutter/material.dart';

import '../models/shopping_trip.dart';
import '../service/receipt_processor_service.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final ReceiptReviewDraft draft;

  const ReceiptReviewScreen({super.key, required this.draft});

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late ShoppingTrip _trip;
  late List<ShoppingTripItem> _items;

  @override
  void initState() {
    super.initState();

    _trip = widget.draft.shoppingTrip;
    _items = List<ShoppingTripItem>.from(_trip.items);
  }

  int get _itemsNeedingReview {
    return _items.where((item) => item.requiresReview).length;
  }

  double get _calculatedSubtotal {
    return _items.fold<double>(0, (total, item) => total + item.lineTotal);
  }

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(3);
  }

  String _confidenceLabel(double score) {
    if (score >= 85) return 'High confidence';
    if (score >= 75) return 'Medium confidence';
    return 'Low confidence';
  }

  IconData _confidenceIcon(double score) {
    if (score >= 85) return Icons.check_circle;
    if (score >= 75) return Icons.warning_amber_rounded;
    return Icons.error_outline;
  }

  Color _confidenceColor(BuildContext context, double score) {
    if (score >= 85) return Colors.green;
    if (score >= 75) return Colors.orange;
    return Theme.of(context).colorScheme.error;
  }

  void _replaceItem(int index, ShoppingTripItem updatedItem) {
    setState(() {
      _items[index] = updatedItem;
    });
  }

  void _toggleReviewed(int index) {
    final item = _items[index];

    _replaceItem(index, item.copyWith(requiresReview: !item.requiresReview));
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];

    final nameController = TextEditingController(text: item.rawReceiptName);

    final quantityController = TextEditingController(
      text: _formatQuantity(item.quantity),
    );

    final lineTotalController = TextEditingController(
      text: item.lineTotal.toStringAsFixed(2),
    );

    final result = await showDialog<ShoppingTripItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Receipt Item'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Receipt item name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: lineTotalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Line total',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final quantity = double.tryParse(
                  quantityController.text.trim(),
                );
                final lineTotal = double.tryParse(
                  lineTotalController.text.trim(),
                );

                if (name.isEmpty ||
                    quantity == null ||
                    quantity <= 0 ||
                    lineTotal == null ||
                    lineTotal < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid name, quantity, and line total.',
                      ),
                    ),
                  );
                  return;
                }

                final unitPrice = lineTotal / quantity;

                Navigator.pop(
                  dialogContext,
                  item.copyWith(
                    rawReceiptName: name,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    lineTotal: lineTotal,
                    requiresReview: false,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
    lineTotalController.dispose();

    if (result == null || !mounted) return;

    _replaceItem(index, result);
  }

  void _removeItem(int index) {
    final removedItem = _items[index];

    setState(() {
      _items.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removedItem.rawReceiptName} removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;

            setState(() {
              final insertIndex = index.clamp(0, _items.length);
              _items.insert(insertIndex, removedItem);
            });
          },
        ),
      ),
    );
  }

  void _markAllReviewed() {
    setState(() {
      _items = _items
          .map((item) => item.copyWith(requiresReview: false))
          .toList();
    });
  }

  void _confirmReceipt() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A receipt must contain at least one item.'),
        ),
      );
      return;
    }

    if (_itemsNeedingReview > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Review the remaining $_itemsNeedingReview item(s) first.',
          ),
        ),
      );
      return;
    }

    final reviewedTrip = _trip.copyWith(
      subtotal: _calculatedSubtotal,
      processingStatus: 'verified',
      items: _items,
    );

    Navigator.pop(context, reviewedTrip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Receipt')),
      body: Column(
        children: [
          _buildSummary(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildItemCard(index, _items[index]);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSummary() {
    final reviewCount = _itemsNeedingReview;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.storefront),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _trip.storeName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${_items.length} item${_items.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Calculated subtotal',
                    value: _formatMoney(_calculatedSubtotal),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Receipt total',
                    value: _formatMoney(_trip.total),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Needs review',
                    value: reviewCount.toString(),
                  ),
                ),
              ],
            ),
            if (reviewCount > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _markAllReviewed,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Accept All Items'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, ShoppingTripItem item) {
    final confidenceColor = _confidenceColor(context, item.confidenceScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.requiresReview ? Icons.pending_actions : Icons.verified,
                  color: item.requiresReview ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.rawReceiptName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editItem(index);
                      case 'remove':
                        _removeItem(index);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Remove'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.numbers,
                  label: 'Qty ${_formatQuantity(item.quantity)}',
                ),
                _InfoChip(
                  icon: Icons.sell_outlined,
                  label: '${_formatMoney(item.unitPrice)} each',
                ),
                _InfoChip(
                  icon: Icons.receipt,
                  label: _formatMoney(item.lineTotal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _confidenceIcon(item.confidenceScore),
                  size: 20,
                  color: confidenceColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_confidenceLabel(item.confidenceScore)} '
                    '(${item.confidenceScore.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _toggleReviewed(index),
                  icon: Icon(item.requiresReview ? Icons.check : Icons.undo),
                  label: Text(item.requiresReview ? 'Accept' : 'Review Again'),
                ),
              ],
            ),
            if (item.product == null) ...[
              const SizedBox(height: 8),
              const Text(
                'No product match was found. You can still accept this '
                'receipt item or edit its details.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72),
            SizedBox(height: 16),
            Text(
              'No receipt items remain.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Material(
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _itemsNeedingReview == 0 ? _confirmReceipt : null,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _itemsNeedingReview == 0
                  ? 'Confirm Receipt'
                  : '$_itemsNeedingReview Item(s) Need Review',
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

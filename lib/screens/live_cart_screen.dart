import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/live_cart_item.dart';
import '../service/live_cart_service.dart';

class LiveCartScreen extends StatefulWidget {
  const LiveCartScreen({super.key});

  @override
  State<LiveCartScreen> createState() =>
      _LiveCartScreenState();
}

class _LiveCartScreenState extends State<LiveCartScreen> {
  void refresh() {
    setState(() {});
  }

  Future<void> clearCart() async {
    final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Cart'),
            content: const Text(
              'Remove all items from the current shopping cart?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldClear) return;

    LiveCartService.clear();
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final items = LiveCartService.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Shopping'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear Cart',
              icon: const Icon(Icons.delete_outline),
              onPressed: clearCart,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Barcode scanner coming next.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Item'),
      ),
      body: items.isEmpty
          ? const _EmptyCart()
          : Column(
              children: [
                _CartSummary(
                  total: LiveCartService.totalCost,
                  itemCount:
                      LiveCartService.itemCount,
                  uniqueItems:
                      LiveCartService.uniqueItemCount,
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _CartItemCard(
                        item: items[index],
                        onChanged: refresh,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double total;
  final int itemCount;
  final int uniqueItems;

  const _CartSummary({
    required this.total,
    required this.itemCount,
    required this.uniqueItems,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'Estimated Checkout',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  value: '$itemCount',
                  label: 'Items',
                ),
              ),
              Expanded(
                child: _SummaryTile(
                  value: '$uniqueItems',
                  label: 'Products',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryTile({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final LiveCartItem item;
  final VoidCallback onChanged;

  const _CartItemCard({
    required this.item,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(item.storeName),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                  ),
                  onPressed: () {
                    LiveCartService.decreaseQuantity(
                      item.barcode,
                    );
                    onChanged();
                  },
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                  ),
                  onPressed: () {
                    LiveCartService.increaseQuantity(
                      item.barcode,
                    );
                    onChanged();
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  onPressed: () {
                    LiveCartService.removeProduct(
                      item.barcode,
                    );
                    onChanged();
                  },
                ),
              ],
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: \$${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Start scanning products to build your cart and see your estimated checkout total in real time.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
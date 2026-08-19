import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';

class CartItemCard extends StatelessWidget {
  static const Color primaryRed = Color(0xFFD6001C);
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  String get productName {
    final parts = [
      item.product.brand,
      item.product.name,
      item.product.size,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return item.product.barcode;
    }

    return parts.join(' ');
  }

  Future<void> _editPrice(BuildContext context) async {
    final controller = TextEditingController(
      text: item.price.toStringAsFixed(2),
    );

    final newPrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Price'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price',
              prefixText: '\$',
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
                final price = double.tryParse(controller.text.trim());

                if (price != null && price >= 0) {
                  Navigator.pop(dialogContext, price);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!context.mounted) return;

    if (newPrice != null) {
      context.read<CartProvider>().updatePrice(item, newPrice);
    }
  }

  Future<void> _editQuantity(BuildContext context) async {
    final controller = TextEditingController(text: item.quantity.toString());

    final newQuantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Quantity'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
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
                final quantity = int.tryParse(controller.text.trim());

                if (quantity != null && quantity >= 0) {
                  Navigator.pop(dialogContext, quantity);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!context.mounted) return;

    if (newQuantity != null) {
      context.read<CartProvider>().setQuantity(item, newQuantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(item: item),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Barcode: ${item.product.barcode}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 7),
                  InkWell(
                    onTap: () {
                      _editPrice(context);
                    },
                    child: Text(
                      '\$${item.price.toStringAsFixed(2)} each',
                      style: const TextStyle(
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.product.taxable ? 'HST applies' : 'No HST',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove,
                        tooltip: 'Decrease quantity',
                        onPressed: onDecrease,
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 44),
                        alignment: Alignment.center,
                        child: InkWell(
                          onTap: () {
                            _editQuantity(context);
                          },
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      _QuantityButton(
                        icon: Icons.add,
                        tooltip: 'Increase quantity',
                        onPressed: onIncrease,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Remove item',
                        onPressed: onRemove,
                        color: primaryRed,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${item.total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final CartItem item;

  const _ProductImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.product.imageUrl.trim();

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? Icon(
              Icons.inventory_2_outlined,
              color: Colors.grey.shade500,
              size: 34,
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.grey.shade500,
                  size: 34,
                );
              },
            ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton.outlined(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

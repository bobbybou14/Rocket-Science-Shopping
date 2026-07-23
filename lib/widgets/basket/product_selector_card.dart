import 'package:flutter/material.dart';

import '../../models/product.dart';

class ProductSelectorCard extends StatelessWidget {
  final Product product;
  final double quantity;
  final VoidCallback onIncrease;
  final VoidCallback? onDecrease;

  const ProductSelectorCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onIncrease,
    this.onDecrease,
  });

  String get productName {
    final parts = [
      product.brand,
      product.name,
      product.size,
    ].where((part) => part.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return product.barcode;
    }

    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(quantity > 0 ? Icons.check : Icons.inventory_2),
            ),
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
                  const SizedBox(height: 4),
                  Text(
                    product.category.trim().isEmpty
                        ? 'No category'
                        : product.category,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 36,
              child: Text(
                quantity.toStringAsFixed(0),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

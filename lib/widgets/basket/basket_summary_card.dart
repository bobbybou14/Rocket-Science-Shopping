import 'package:flutter/material.dart';

class BasketSummaryCard extends StatelessWidget {
  final int selectedProductCount;
  final double selectedUnitCount;
  final VoidCallback? onClear;

  const BasketSummaryCard({
    super.key,
    required this.selectedProductCount,
    required this.selectedUnitCount,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.shopping_cart)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Basket',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$selectedProductCount product'
                    '${selectedProductCount == 1 ? '' : 's'} • '
                    '${selectedUnitCount.toStringAsFixed(0)} total item'
                    '${selectedUnitCount == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
      ),
    );
  }
}

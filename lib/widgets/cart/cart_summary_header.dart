import 'package:flutter/material.dart';

import '../../providers/cart_provider.dart';

class CartSummaryHeader extends StatelessWidget {
  final CartProvider cart;

  const CartSummaryHeader({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(Icons.shopping_basket, color: Color(0xFFD6001C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${cart.uniqueItemCount} unique '
              '${cart.uniqueItemCount == 1 ? "product" : "products"}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${cart.itemCount} '
            '${cart.itemCount == 1 ? "item" : "items"}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../providers/cart_provider.dart';

class CartTotals extends StatelessWidget {
  final CartProvider cart;
  final VoidCallback onCompareStores;

  const CartTotals({
    super.key,
    required this.cart,
    required this.onCompareStores,
  });

  Widget totalRow({
    required String label,
    required double amount,
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasized ? 20 : 16,
                fontWeight: emphasized
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: emphasized ? 24 : 16,
              fontWeight: emphasized
                  ? FontWeight.bold
                  : FontWeight.w600,
              color: emphasized
                  ? const Color(0xFFD6001C)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              totalRow(
                label: 'Subtotal',
                amount: cart.subtotal,
              ),
              totalRow(
                label: 'Estimated tax',
                amount: cart.tax,
              ),
              const Divider(height: 18),
              totalRow(
                label: 'Estimated total',
                amount: cart.total,
                emphasized: true,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCompareStores,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFD6001C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                  ),
                  icon: const Icon(
                    Icons.compare_arrows,
                  ),
                  label: const Text(
                    'Compare This Basket',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
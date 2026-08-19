import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/cart/cart_search_bar.dart';
import '../widgets/cart/cart_item_card.dart';
import '../widgets/cart/cart_totals.dart';
import '../widgets/cart/cart_summary_header.dart';
import '../widgets/cart/empty_cart.dart';
import '../models/shopping_trip.dart';
import '../providers/cart_provider.dart';
import '../service/basket_comparison_service.dart';
import '../service/shopping_session_service.dart';
import '../service/shopping_trip_service.dart';
import 'basket_comparison_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  static const Color primaryRed = Color(0xFFD6001C);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  Future<void> _confirmClearCart(
    BuildContext context,
    CartProvider cart,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear cart?'),
          content: const Text('This will remove every item from your cart.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: CartScreen.primaryRed,
              ),
              child: const Text('Clear Cart'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      cart.clear();

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart cleared.')));
    }
  }

  void _openBasketComparison(BuildContext context, CartProvider cart) {
    final basketItems = cart.items
        .map(
          (item) => BasketItemRequest(
            product: item.product,
            quantity: item.quantity.toDouble(),
          ),
        )
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BasketComparisonScreen(initialItems: basketItems),
      ),
    );
  }

  Future<void> _finishShopping(BuildContext context, CartProvider cart) async {
    if (cart.isEmpty) {
      return;
    }

    final storeName = ShoppingSessionService.currentStoreName.trim();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Finish Shopping?'),
          content: Text(
            'Store: ${storeName.isEmpty ? "Current Store" : storeName}\n'
            'Items: ${cart.itemCount}\n'
            'Subtotal: \$${cart.subtotal.toStringAsFixed(2)}\n'
            'Estimated tax: \$${cart.tax.toStringAsFixed(2)}\n'
            'Estimated total: \$${cart.total.toStringAsFixed(2)}\n\n'
            'This will save the shopping trip and clear the active cart.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep Shopping'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Finish and Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true || !context.mounted) {
      return;
    }

    final tripItems = cart.items.map((item) {
      return ShoppingTripItem(
        id: '',
        shoppingTripId: '',
        rawReceiptName: item.product.name,
        product: item.product,
        barcode: item.barcode,
        quantity: item.quantity.toDouble(),
        unitPrice: item.price,
        lineTotal: item.subtotal,
        confidenceScore: 100,
        requiresReview: false,
      );
    }).toList();

    final shoppingTrip = ShoppingTrip(
      id: '',
      storeId: '',
      storeName: storeName.isEmpty ? 'Current Store' : storeName,
      city: '',
      province: 'Ontario',
      purchaseDate: DateTime.now(),
      subtotal: cart.subtotal,
      tax: cart.tax,
      total: cart.total,
      source: 'live_shopping',
      processingStatus: 'confirmed',
      items: tripItems,
    );

    try {
      final savedTrip = await ShoppingTripService.saveShoppingTrip(
        shoppingTrip,
      );

      cart.clear();
      ShoppingSessionService.endSession();

      if (!context.mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Shopping Trip Saved'),
            content: Text(
              'Your shopping trip was saved successfully.\n\n'
              'Store: ${savedTrip.storeName}\n'
              'Items: ${savedTrip.items.length}\n'
              'Total: \$${savedTrip.total.toStringAsFixed(2)}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shopping trip could not be saved: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final filteredItems = cart.items.where((item) {
      if (_searchText.isEmpty) {
        return true;
      }

      final search = _searchText;

      return item.product.name.toLowerCase().contains(search) ||
          item.product.brand.toLowerCase().contains(search) ||
          item.product.barcode.toLowerCase().contains(search) ||
          item.product.size.toLowerCase().contains(search);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: CartScreen.primaryRed,
        foregroundColor: Colors.white,
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              tooltip: 'Clear cart',
              onPressed: () {
                _confirmClearCart(context, cart);
              },
              icon: const Icon(Icons.delete_sweep),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const EmptyCart()
          : Column(
              children: [
                CartSummaryHeader(cart: cart),

                CartSearchBar(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchText = value.toLowerCase().trim();
                    });
                  },
                ),

                Expanded(
                  child: filteredItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching items',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, _) {
                            return const SizedBox(height: 12);
                          },
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];

                            return Dismissible(
                              key: ValueKey(item.product.barcode),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                color: Colors.red,
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              onDismissed: (_) {
                                cart.removeItem(item);

                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${item.product.name} removed',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () {
                                        cart.restoreItem(item);
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: CartItemCard(
                                item: item,
                                onIncrease: () {
                                  cart.increaseQuantity(item);
                                },
                                onDecrease: () {
                                  cart.decreaseQuantity(item);
                                },
                                onRemove: () {
                                  cart.removeItem(item);
                                },
                              ),
                            );
                          },
                        ),
                ),
                CartTotals(
                  cart: cart,
                  onFinishShopping: () {
                    _finishShopping(context, cart);
                  },
                  onCompareStores: () {
                    _openBasketComparison(context, cart);
                  },
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

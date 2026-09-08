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
    final result = await Navigator.push<_PriceEditResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _EditCartItemPriceScreen(
          initialPrice: item.price,
          initialTaxable: item.taxable,
        ),
      ),
    );

    if (!context.mounted || result == null) return;

    context.read<CartProvider>().updatePrice(
      item,
      result.price,
      taxable: result.taxable,
    );
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
                    item.taxable ? 'HST applies' : 'No HST',
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
              errorBuilder: (context, error, stackTrace) {
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

class _PriceEditResult {
  final double price;
  final bool taxable;

  const _PriceEditResult({required this.price, required this.taxable});
}

class _EditCartItemPriceScreen extends StatefulWidget {
  final double initialPrice;
  final bool initialTaxable;

  const _EditCartItemPriceScreen({
    required this.initialPrice,
    required this.initialTaxable,
  });

  @override
  State<_EditCartItemPriceScreen> createState() =>
      _EditCartItemPriceScreenState();
}

class _EditCartItemPriceScreenState extends State<_EditCartItemPriceScreen> {
  static const Color primaryRed = Color(0xFFD6001C);

  late final TextEditingController priceController;
  late bool taxApplies;

  @override
  void initState() {
    super.initState();

    priceController = TextEditingController(
      text: widget.initialPrice.toStringAsFixed(2),
    );
    taxApplies = widget.initialTaxable;
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  void save() {
    final price = double.tryParse(priceController.text.trim());

    if (price == null || price < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
      return;
    }

    FocusScope.of(context).unfocus();

    Navigator.pop(context, _PriceEditResult(price: price, taxable: taxApplies));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Price'),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: priceController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  save();
                },
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: '\$',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                    },
                    icon: const Icon(Icons.keyboard_hide),
                    tooltip: 'Hide keyboard',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile.adaptive(
                  title: const Text('Tax applies'),
                  subtitle: Text(
                    taxApplies
                        ? 'Ontario HST will be added'
                        : 'No HST will be added',
                  ),
                  value: taxApplies,
                  onChanged: (value) {
                    setState(() {
                      taxApplies = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: save,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

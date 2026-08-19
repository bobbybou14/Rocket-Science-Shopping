import 'package:flutter/material.dart';

import '../models/product.dart';
import '../service/basket_comparison_service.dart';
import '../service/product_service.dart';
import '../widgets/basket/basket_summary_card.dart';
import '../widgets/basket/comparison_results.dart';
import '../widgets/basket/product_selector_card.dart';

class BasketComparisonScreen extends StatefulWidget {
  final List<BasketItemRequest> initialItems;

  const BasketComparisonScreen({super.key, this.initialItems = const []});

  @override
  State<BasketComparisonScreen> createState() => _BasketComparisonScreenState();
}

class _BasketComparisonScreenState extends State<BasketComparisonScreen> {
  final Map<String, double> selectedQuantities = {};

  List<Product> products = [];
  BasketComparisonResult? comparisonResult;

  bool isLoadingProducts = true;
  bool isComparing = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    for (final item in widget.initialItems) {
      selectedQuantities[item.product.barcode] = item.quantity;
    }

    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() {
      isLoadingProducts = true;
      errorMessage = null;
    });

    try {
      final loadedProducts = await ProductService.getProducts();

      for (final initialItem in widget.initialItems) {
        final alreadyIncluded = loadedProducts.any(
          (product) => product.barcode == initialItem.product.barcode,
        );

        if (!alreadyIncluded) {
          loadedProducts.add(initialItem.product);
        }
      }

      loadedProducts.sort(
        (a, b) => _productDisplayName(a).compareTo(_productDisplayName(b)),
      );

      if (!mounted) return;

      setState(() {
        products = loadedProducts;
        isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingProducts = false;
        errorMessage = 'Unable to load products: $error';
      });
    }
  }

  Future<void> compareBasket() async {
    final basketItems = products
        .where((product) => (selectedQuantities[product.barcode] ?? 0) > 0)
        .map(
          (product) => BasketItemRequest(
            product: product,
            quantity: selectedQuantities[product.barcode] ?? 1,
          ),
        )
        .toList();

    if (basketItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one product before comparing.'),
        ),
      );
      return;
    }

    setState(() {
      isComparing = true;
      comparisonResult = null;
      errorMessage = null;
    });

    try {
      final result = await BasketComparisonService.compareBasket(basketItems);

      if (!mounted) return;

      setState(() {
        comparisonResult = result;
        isComparing = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isComparing = false;
        errorMessage = 'Unable to compare basket: $error';
      });
    }
  }

  void increaseQuantity(Product product) {
    setState(() {
      final current = selectedQuantities[product.barcode] ?? 0;

      selectedQuantities[product.barcode] = current + 1;
      comparisonResult = null;
    });
  }

  void decreaseQuantity(Product product) {
    setState(() {
      final current = selectedQuantities[product.barcode] ?? 0;

      if (current <= 1) {
        selectedQuantities.remove(product.barcode);
      } else {
        selectedQuantities[product.barcode] = current - 1;
      }

      comparisonResult = null;
    });
  }

  void clearBasket() {
    setState(() {
      selectedQuantities.clear();
      comparisonResult = null;
    });
  }

  String _productDisplayName(Product product) {
    final parts = [
      product.brand,
      product.name,
      product.size,
    ].where((value) => value.trim().isNotEmpty).toList();

    return parts.isEmpty ? product.barcode : parts.join(' ');
  }

  int get selectedProductCount {
    return selectedQuantities.values.where((quantity) => quantity > 0).length;
  }

  double get selectedUnitCount {
    return selectedQuantities.values.fold<double>(
      0,
      (total, quantity) => total + quantity,
    );
  }

  Widget loadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60),
            const SizedBox(height: 16),
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyProductsState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 56),
            SizedBox(height: 14),
            Text(
              'No Products Available',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Add products to Rocket Science Shopping before building a basket comparison.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget inlineError() {
    if (errorMessage == null || products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget bodyContent() {
    if (isLoadingProducts) {
      return loadingState();
    }

    if (errorMessage != null && products.isEmpty) {
      return errorState();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Basket Comparison',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose products and quantities, then compare the latest recorded prices across stores.',
          style: TextStyle(fontSize: 17),
        ),
        const SizedBox(height: 18),
        BasketSummaryCard(
          selectedProductCount: selectedProductCount,
          selectedUnitCount: selectedUnitCount,
          onClear: selectedQuantities.isEmpty ? null : clearBasket,
        ),
        const SizedBox(height: 18),
        if (products.isEmpty)
          emptyProductsState()
        else
          ...products.map(
            (product) => ProductSelectorCard(
              product: product,
              quantity: selectedQuantities[product.barcode] ?? 0,
              onIncrease: () => increaseQuantity(product),
              onDecrease: (selectedQuantities[product.barcode] ?? 0) <= 0
                  ? null
                  : () => decreaseQuantity(product),
            ),
          ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isComparing ? null : compareBasket,
            icon: isComparing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.compare_arrows),
            label: Text(isComparing ? 'Comparing...' : 'Compare Basket'),
          ),
        ),
        inlineError(),
        if (comparisonResult != null)
          ComparisonResults(result: comparisonResult!),
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basket Comparison'),
        actions: [
          IconButton(
            onPressed: isLoadingProducts || isComparing ? null : loadProducts,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: bodyContent(),
    );
  }
}

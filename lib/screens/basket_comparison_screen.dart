import 'dart:async';

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
  static const int _pageSize = 50;

  final TextEditingController _searchController = TextEditingController();
  final Map<String, double> selectedQuantities = {};
  final Map<String, Product> _knownProducts = {};

  List<Product> products = [];
  BasketComparisonResult? comparisonResult;

  Timer? _searchDebounce;
  String _searchText = '';
  String? _productError;
  String? _comparisonError;

  bool isLoadingProducts = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool isComparing = false;

  int _nextOffset = 0;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();

    for (final item in widget.initialItems) {
      _knownProducts[item.product.barcode] = item.product;

      if (item.quantity > 0) {
        selectedQuantities.update(
          item.product.barcode,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }

    loadProducts();
  }

  Future<void> loadProducts({bool append = false}) async {
    if (!mounted) return;

    if (append && (isLoadingProducts || _isLoadingMore || !_hasMore)) {
      return;
    }

    if (!append) {
      _searchDebounce?.cancel();
    }

    final requestId = ++_requestId;
    final query = _searchText;
    final offset = append ? _nextOffset : 0;

    setState(() {
      _productError = null;

      if (append) {
        _isLoadingMore = true;
      } else {
        isLoadingProducts = true;
        _isLoadingMore = false;
        _hasMore = false;
      }
    });

    try {
      final response = await ProductService.searchProducts(
        search: query,
        offset: offset,
        pageSize: _pageSize,
      );

      if (!mounted || requestId != _requestId) return;

      final page = response.take(_pageSize).toList();

      setState(() {
        for (final product in page) {
          _knownProducts[product.barcode] = product;
        }

        if (append) {
          final existingBarcodes = products
              .map((product) => product.barcode)
              .toSet();

          final additions = page.where(
            (product) => existingBarcodes.add(product.barcode),
          );

          products = [...products, ...additions];
        } else {
          products = page;
        }

        _nextOffset = offset + page.length;
        _hasMore = response.length > _pageSize;
        isLoadingProducts = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        isLoadingProducts = false;
        _isLoadingMore = false;
        _productError = 'Unable to load products: $error';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    ++_requestId;

    setState(() {
      _searchText = value;
      products = [];
      isLoadingProducts = true;
      _isLoadingMore = false;
      _hasMore = false;
      _productError = null;
      _nextOffset = 0;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      loadProducts();
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchText = '';
    });

    loadProducts();
  }

  Future<void> compareBasket() async {
    if (isComparing) return;

    if (selectedQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one product before comparing.'),
        ),
      );
      return;
    }

    final basketItems = <BasketItemRequest>[];

    for (final entry in selectedQuantities.entries) {
      if (entry.value <= 0) continue;

      final product = _knownProducts[entry.key];

      if (product == null) {
        setState(() {
          _comparisonError =
              'A selected product could not be loaded. '
              'Remove it and select it again.';
        });
        return;
      }

      basketItems.add(
        BasketItemRequest(product: product, quantity: entry.value),
      );
    }

    if (basketItems.isEmpty) return;

    setState(() {
      isComparing = true;
      comparisonResult = null;
      _comparisonError = null;
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
        _comparisonError = 'Unable to compare basket: $error';
      });
    }
  }

  void increaseQuantity(Product product) {
    if (isComparing) return;

    setState(() {
      _knownProducts[product.barcode] = product;

      final current = selectedQuantities[product.barcode] ?? 0;
      selectedQuantities[product.barcode] = current + 1;

      comparisonResult = null;
      _comparisonError = null;
    });
  }

  void decreaseQuantity(Product product) {
    if (isComparing) return;

    setState(() {
      final current = selectedQuantities[product.barcode] ?? 0;

      if (current <= 1) {
        selectedQuantities.remove(product.barcode);
      } else {
        selectedQuantities[product.barcode] = current - 1;
      }

      comparisonResult = null;
      _comparisonError = null;
    });
  }

  void clearBasket() {
    if (isComparing) return;

    setState(() {
      selectedQuantities.clear();
      comparisonResult = null;
      _comparisonError = null;
    });
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

  List<Product> get _selectedProducts {
    return selectedQuantities.keys
        .map((barcode) => _knownProducts[barcode])
        .whereType<Product>()
        .toList();
  }

  Widget _productCard(Product product) {
    final quantity = selectedQuantities[product.barcode] ?? 0;

    return ProductSelectorCard(
      product: product,
      quantity: quantity,
      onIncrease: () => increaseQuantity(product),
      onDecrease: quantity <= 0 || isComparing
          ? null
          : () => decreaseQuantity(product),
    );
  }

  Widget _errorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    ++_requestId;
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProducts = _selectedProducts;

    final visibleProducts = products
        .where((product) => !selectedQuantities.containsKey(product.barcode))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Basket Comparison'),
        actions: [
          IconButton(
            onPressed: isLoadingProducts || isComparing
                ? null
                : () {
                    loadProducts();
                  },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Basket Comparison',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose products and quantities, then compare the latest '
            'recorded prices across stores.',
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 18),
          BasketSummaryCard(
            selectedProductCount: selectedProductCount,
            selectedUnitCount: selectedUnitCount,
            onClear: selectedQuantities.isEmpty || isComparing
                ? null
                : clearBasket,
          ),
          if (selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Selected products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...selectedProducts.map(_productCard),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isComparing || selectedQuantities.isEmpty
                  ? null
                  : compareBasket,
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
          if (_comparisonError != null) _errorMessage(_comparisonError!),
          if (comparisonResult != null)
            ComparisonResults(result: comparisonResult!),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search the full catalogue',
              hintText: 'Name, brand, category, size, or barcode',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 16),
          if (isLoadingProducts)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_productError != null) ...[
              _errorMessage(_productError!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    loadProducts(append: products.isNotEmpty);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ),
            ],
            if (products.isEmpty && _productError == null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _searchText.trim().isEmpty
                      ? 'No products are available.'
                      : 'No products match your search.',
                  textAlign: TextAlign.center,
                ),
              ),
            ...visibleProducts.map(_productCard),
            if (products.isNotEmpty && visibleProducts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'All products on this page are already selected.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasMore && _productError == null)
              OutlinedButton.icon(
                onPressed: () {
                  loadProducts(append: true);
                },
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more products'),
              ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

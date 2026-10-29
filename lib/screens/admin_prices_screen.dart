import 'dart:async';

import 'package:flutter/material.dart';

import '../models/measurement_unit.dart';
import '../models/price.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../service/price_service.dart';
import '../service/product_service.dart';
import '../service/store_service.dart';
import 'admin_price_store_search_screen.dart';

class AdminPricesScreen extends StatefulWidget {
  const AdminPricesScreen({super.key});

  @override
  State<AdminPricesScreen> createState() => _AdminPricesScreenState();
}

class _AdminPricesScreenState extends State<AdminPricesScreen> {
  static const Color primaryRed = Color(0xFFD6001C);
  static const int _pageSize = 50;

  final priceController = TextEditingController();
  final productSearchController = TextEditingController();

  List<Product> products = [];
  List<Store> stores = [];

  Product? selectedProduct;
  Store? selectedStore;

  MeasurementUnit selectedPriceUnit = MeasurementUnit.each;

  Timer? _searchDebounce;
  String productSearchText = '';
  String? _searchError;
  String? _storeError;

  bool loading = true;
  bool saving = false;
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasMore = false;

  int _requestId = 0;
  int _nextOffset = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    ++_requestId;
    priceController.dispose();
    productSearchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      _storeError = null;
    });

    try {
      final loadedStores = await StoreService.getStores();

      if (!mounted) return;

      setState(() {
        stores = loadedStores;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
        _storeError = 'Unable to load stores: $error';
      });
    }
  }

  void _onProductSearchChanged(String value) {
    if (saving) return;

    _searchDebounce?.cancel();
    ++_requestId;

    setState(() {
      productSearchText = value;
      selectedProduct = null;
      selectedPriceUnit = MeasurementUnit.each;
      products = [];
      _searchError = null;
      _nextOffset = 0;
      _hasMore = false;
      _loadingMore = false;
      _searching = value.trim().isNotEmpty;
    });

    if (value.trim().isNotEmpty) {
      _searchDebounce = Timer(const Duration(milliseconds: 400), () {
        _searchProducts();
      });
    }
  }

  Future<void> _searchProducts({bool append = false}) async {
    if (!mounted || saving) return;

    final query = productSearchText.trim();

    if (query.isEmpty) return;

    if (append && (_searching || _loadingMore || !_hasMore)) {
      return;
    }

    _searchDebounce?.cancel();

    final requestId = ++_requestId;
    final offset = append ? _nextOffset : 0;

    setState(() {
      _searchError = null;

      if (append) {
        _loadingMore = true;
      } else {
        _searching = true;
        _loadingMore = false;
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
        _searching = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _searching = false;
        _loadingMore = false;
        _searchError = 'Unable to search products: $error';
      });
    }
  }

  List<MeasurementUnit> get availablePriceUnits {
    final product = selectedProduct;

    if (product == null) {
      return const [MeasurementUnit.each];
    }

    if (product.isWeight) {
      return const [
        MeasurementUnit.pound,
        MeasurementUnit.kilogram,
        MeasurementUnit.ounce,
        MeasurementUnit.gram,
      ];
    }

    if (product.isVolume) {
      return const [MeasurementUnit.litre, MeasurementUnit.millilitre];
    }

    return const [MeasurementUnit.each, MeasurementUnit.package];
  }

  void selectProduct(Product product) {
    if (saving) return;

    _searchDebounce?.cancel();
    ++_requestId;

    setState(() {
      selectedProduct = product;

      if (product.isWeight) {
        selectedPriceUnit = MeasurementUnit.pound;
      } else if (product.isVolume) {
        selectedPriceUnit = MeasurementUnit.litre;
      } else {
        selectedPriceUnit = MeasurementUnit.each;
      }

      productSearchController.text = product.name;
      productSearchText = '';
      products = [];
      _searchError = null;
      _searching = false;
      _loadingMore = false;
      _hasMore = false;
      _nextOffset = 0;
    });

    FocusScope.of(context).unfocus();
  }

  void clearSelectedProduct() {
    if (saving) return;

    _searchDebounce?.cancel();
    ++_requestId;

    setState(() {
      selectedProduct = null;
      selectedPriceUnit = MeasurementUnit.each;
      productSearchController.clear();
      productSearchText = '';
      products = [];
      _searchError = null;
      _searching = false;
      _loadingMore = false;
      _hasMore = false;
      _nextOffset = 0;
    });
  }

  Future<void> selectStore() async {
    if (saving) return;

    FocusScope.of(context).unfocus();

    final result = await Navigator.push<Store>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPriceStoreSearchScreen(stores: stores),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      selectedStore = result;
    });
  }

  Future<void> savePrice() async {
    if (saving) return;

    final product = selectedProduct;
    final store = selectedStore;

    if (product == null ||
        store == null ||
        priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a product, store, and enter a price.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(priceController.text.trim());

    if (amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final price = Price(
        id: '',
        barcode: product.barcode,
        storeId: store.id,
        store: store.name,
        province: store.province,
        city: store.city,
        price: amount,
        advertisedUnit: selectedPriceUnit,
        measurementQuantity: 1,
        normalizedUnit: product.baseUnit,
      );

      await PriceService.savePrice(price);

      if (!mounted) return;

      _searchDebounce?.cancel();
      ++_requestId;

      setState(() {
        saving = false;
        priceController.clear();
        productSearchController.clear();
        productSearchText = '';
        products = [];
        selectedProduct = null;
        selectedStore = null;
        selectedPriceUnit = MeasurementUnit.each;
        _searchError = null;
        _searching = false;
        _loadingMore = false;
        _hasMore = false;
        _nextOffset = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Price could not be saved: $error')),
      );
    }
  }

  Widget _buildProductSearchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_searchError != null) ...[
          Text(
            _searchError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton.icon(
            onPressed: saving
                ? null
                : () {
                    _searchProducts(append: products.isNotEmpty);
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
        if (products.isEmpty && _searchError == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'No matching products found.',
              textAlign: TextAlign.center,
            ),
          ),
        if (products.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: products.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = products[index];

                final details = [
                  if (product.brand.trim().isNotEmpty) product.brand,
                  if (product.size.trim().isNotEmpty) product.size,
                  if (product.category.trim().isNotEmpty) product.category,
                ].join(' • ');

                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product.name),
                  subtitle: Text(
                    details.isEmpty
                        ? product.barcode
                        : '$details\n${product.barcode}',
                  ),
                  isThreeLine: details.isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: saving ? null : () => selectProduct(product),
                );
              },
            ),
          ),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_hasMore && _searchError == null)
          TextButton.icon(
            onPressed: saving
                ? null
                : () {
                    _searchProducts(append: true);
                  },
            icon: const Icon(Icons.expand_more),
            label: const Text('Load more products'),
          ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: productSearchController,
            enabled: !saving,
            decoration: InputDecoration(
              labelText: 'Search the full product catalogue',
              hintText: 'Name, brand, category, size, or barcode',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: productSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear product',
                      onPressed: saving ? null : clearSelectedProduct,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: _onProductSearchChanged,
          ),
          if (productSearchText.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildProductSearchResults(),
          ],
          if (selectedProduct != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryRed.withValues(alpha: 0.06),
                border: Border.all(color: primaryRed.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: primaryRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Product',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          selectedProduct!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (selectedProduct!.brand.trim().isNotEmpty)
                          Text(selectedProduct!.brand),
                        if (selectedProduct!.size.trim().isNotEmpty)
                          Text(selectedProduct!.size),
                        Text(selectedProduct!.barcode),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          InkWell(
            onTap: saving ? null : selectStore,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Store',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.arrow_forward_ios, size: 18),
                border: OutlineInputBorder(),
              ),
              isEmpty: false,
              child: Text(
                selectedStore?.toString() ?? 'Search by name, address, or city',
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: priceController,
            enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price',
              prefixText: '\$',
              suffixText: '/ ${selectedPriceUnit.symbol}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MeasurementUnit>(
            key: ValueKey(
              '${selectedProduct?.barcode ?? "none"}-'
              '${selectedPriceUnit.databaseValue}',
            ),
            initialValue: availablePriceUnits.contains(selectedPriceUnit)
                ? selectedPriceUnit
                : availablePriceUnits.first,
            decoration: const InputDecoration(
              labelText: 'Price Unit',
              border: OutlineInputBorder(),
            ),
            items: availablePriceUnits.map((unit) {
              return DropdownMenuItem<MeasurementUnit>(
                value: unit,
                child: Text(
                  unit == MeasurementUnit.each
                      ? 'Each'
                      : unit == MeasurementUnit.package
                      ? 'Package'
                      : 'Per ${unit.symbol}',
                ),
              );
            }).toList(),
            onChanged: selectedProduct == null || saving
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      selectedPriceUnit = value;
                    });
                  },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: saving ? null : savePrice,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Saving...' : 'Save Price'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Prices'),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _storeError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_storeError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : _buildForm(),
    );
  }
}

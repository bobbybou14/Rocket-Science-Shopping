import 'package:flutter/material.dart';

import '../models/measurement_unit.dart';
import '../models/price.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../service/price_service.dart';
import '../service/store_service.dart';
import '../service/supabase_product_service.dart';

class AdminPricesScreen extends StatefulWidget {
  const AdminPricesScreen({super.key});

  @override
  State<AdminPricesScreen> createState() => _AdminPricesScreenState();
}

class _AdminPricesScreenState extends State<AdminPricesScreen> {
  static const Color primaryRed = Color(0xFFD6001C);
  List<Product> products = [];
  List<Store> stores = [];

  Product? selectedProduct;
  Store? selectedStore;

  MeasurementUnit selectedPriceUnit = MeasurementUnit.each;

  final priceController = TextEditingController();
  final productSearchController = TextEditingController();

  String productSearchText = '';

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    priceController.dispose();
    productSearchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final loadedProducts = await SupabaseProductService.getProducts();
    final loadedStores = await StoreService.getStores();

    if (!mounted) return;

    setState(() {
      products = loadedProducts;
      stores = loadedStores;
      loading = false;
    });
  }

  List<Product> get filteredProducts {
    final query = productSearchText.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    return products.where((product) {
      final searchable =
          '${product.name} '
                  '${product.brand} '
                  '${product.category} '
                  '${product.size} '
                  '${product.barcode}'
              .toLowerCase();

      return searchable.contains(query);
    }).toList();
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
    });

    FocusScope.of(context).unfocus();
  }

  void clearSelectedProduct() {
    setState(() {
      selectedProduct = null;
      selectedPriceUnit = MeasurementUnit.each;
      productSearchController.clear();
      productSearchText = '';
    });
  }

  Future<void> savePrice() async {
    if (selectedProduct == null ||
        selectedStore == null ||
        priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a product, store, and enter a price.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(priceController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
      return;
    }

    setState(() {
      saving = true;
    });

    final product = selectedProduct!;
    final store = selectedStore!;

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

    try {
      await PriceService.savePrice(price);

      if (!mounted) return;

      setState(() {
        saving = false;
        priceController.clear();
        productSearchController.clear();
        productSearchText = '';
        selectedProduct = null;
        selectedStore = null;
        selectedPriceUnit = MeasurementUnit.each;
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

  @override
  Widget build(BuildContext context) {
    final matches = filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Prices'),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: productSearchController,
                    enabled: !saving,
                    decoration: InputDecoration(
                      labelText: 'Search products',
                      hintText: 'Name, brand, category, size, or barcode',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: productSearchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear product',
                              onPressed: clearSelectedProduct,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        productSearchText = value;
                        selectedProduct = null;
                        selectedPriceUnit = MeasurementUnit.each;
                      });
                    },
                  ),

                  if (productSearchText.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),

                    if (matches.isEmpty)
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
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: matches.length,
                          separatorBuilder: (_, _) {
                            return const Divider(height: 1);
                          },
                          itemBuilder: (context, index) {
                            final product = matches[index];

                            final details = [
                              if (product.brand.trim().isNotEmpty)
                                product.brand,
                              if (product.size.trim().isNotEmpty) product.size,
                              if (product.category.trim().isNotEmpty)
                                product.category,
                            ].join(' • ');

                            return ListTile(
                              leading: const Icon(Icons.inventory_2_outlined),
                              title: Text(product.name),
                              subtitle: details.isEmpty
                                  ? Text(product.barcode)
                                  : Text(
                                      '$details\n'
                                      '${product.barcode}',
                                    ),
                              isThreeLine: details.isNotEmpty,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                selectProduct(product);
                              },
                            );
                          },
                        ),
                      ),
                  ],

                  if (selectedProduct != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primaryRed.withValues(alpha: 0.06),
                        border: Border.all(
                          color: primaryRed.withValues(alpha: 0.35),
                        ),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  selectedProduct!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (selectedProduct!.brand.trim().isNotEmpty)
                                  Text(selectedProduct!.brand),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  DropdownButtonFormField<Store>(
                    initialValue: selectedStore,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Store',
                      border: OutlineInputBorder(),
                    ),
                    items: stores.map((store) {
                      return DropdownMenuItem<Store>(
                        value: store,
                        child: Text(
                          [
                            store.name,
                            if (store.address.trim().isNotEmpty) store.address,
                            if (store.city.trim().isNotEmpty) store.city,
                          ].join(' - '),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              selectedStore = value;
                            });
                          },
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: priceController,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    initialValue:
                        availablePriceUnits.contains(selectedPriceUnit)
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : savePrice,
                      icon: const Icon(Icons.save),
                      label: Text(saving ? 'Saving...' : 'Save Price'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

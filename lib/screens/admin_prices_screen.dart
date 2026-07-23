import 'package:flutter/material.dart';

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
  static const Color smartCartRed = Color(0xFFD6001C);

  List<Product> products = [];
  List<Store> stores = [];

  Product? selectedProduct;
  Store? selectedStore;

  final priceController = TextEditingController();

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
    super.dispose();
  }

  Future<void> loadData() async {
    final loadedProducts = await SupabaseProductService.getProducts();
    final loadedStores = await StoreService.getStores();

    setState(() {
      products = loadedProducts;
      stores = loadedStores;
      loading = false;
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

    if (amount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
      return;
    }

    setState(() {
      saving = true;
    });

    final price = Price(
      id: '',
      barcode: selectedProduct!.barcode,
      storeId: selectedStore!.id,
      store: selectedStore!.name,
      province: selectedStore!.province,
      city: selectedStore!.city,
      price: amount,
    );

    await PriceService.savePrice(price);

    setState(() {
      saving = false;
      priceController.clear();
      selectedProduct = null;
      selectedStore = null;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Price saved successfully.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Prices'),
        backgroundColor: smartCartRed,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<Product>(
                    initialValue: selectedProduct,
                    decoration: const InputDecoration(
                      labelText: 'Product',
                      border: OutlineInputBorder(),
                    ),
                    items: products.map((product) {
                      return DropdownMenuItem<Product>(
                        value: product,
                        child: Text(product.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProduct = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Store>(
                    initialValue: selectedStore,
                    decoration: const InputDecoration(
                      labelText: 'Store',
                      border: OutlineInputBorder(),
                    ),
                    items: stores.map((store) {
                      return DropdownMenuItem<Store>(
                        value: store,
                        child: Text('${store.name} - ${store.city}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStore = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : savePrice,
                      icon: const Icon(Icons.save),
                      label: Text(saving ? 'Saving...' : 'Save Price'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: smartCartRed,
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

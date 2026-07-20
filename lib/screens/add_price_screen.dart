import 'package:flutter/material.dart';

import '../models/price.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../service/price_service.dart';
import '../service/store_service.dart';

class AddPriceScreen extends StatefulWidget {
  final Product product;

  const AddPriceScreen({
    super.key,
    required this.product,
  });

  @override
  State<AddPriceScreen> createState() => _AddPriceScreenState();
}

class _AddPriceScreenState extends State<AddPriceScreen> {
  static const Color smartCartRed = Color(0xFFD6001C);

  List<Store> stores = [];
  Store? selectedStore;

  final priceController = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  Future<void> loadStores() async {
    final results = await StoreService.getStores();

    setState(() {
      stores = results;
      loading = false;
    });
  }

  Future<void> save() async {
    if (selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a store.')),
      );
      return;
    }

    final amount = double.tryParse(priceController.text);

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price.')),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    await PriceService.savePrice(
      Price(
        id: '',
        barcode: widget.product.barcode,
        storeId: selectedStore!.id,
        store: selectedStore!.name,
        province: selectedStore!.province,
        city: selectedStore!.city,
        price: amount,
      ),
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Price"),
        backgroundColor: smartCartRed,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  DropdownButtonFormField<Store>(
                    decoration: const InputDecoration(
                      labelText: 'Store',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selectedStore,
                    items: stores.map((store) {
                      return DropdownMenuItem(
                        value: store,
                        child: Text(
                          '${store.name} (${store.city})',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStore = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : save,
                      icon: const Icon(Icons.save),
                      label: Text(
                        saving ? 'Saving...' : 'Save Price',
                      ),
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
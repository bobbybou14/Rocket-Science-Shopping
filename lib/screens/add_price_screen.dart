import 'package:flutter/material.dart';

import '../models/price.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../service/price_service.dart';
import '../service/store_service.dart';

class AddPriceScreen extends StatefulWidget {
  final Product product;

  const AddPriceScreen({super.key, required this.product});

  @override
  State<AddPriceScreen> createState() => _AddPriceScreenState();
}

class _AddPriceScreenState extends State<AddPriceScreen> {
  static const Color primaryRed = Color(0xFFD6001C);

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

    if (!mounted) return;

    setState(() {
      stores = results;
      loading = false;
    });
  }

  Future<void> selectStore() async {
    FocusScope.of(context).unfocus();

    final result = await Navigator.push<Store>(
      context,
      MaterialPageRoute(builder: (_) => _StoreSearchScreen(stores: stores)),
    );

    if (result == null || !mounted) return;

    setState(() {
      selectedStore = result;
    });
  }

  Future<void> save() async {
    final store = selectedStore;

    if (store == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a store.')));
      return;
    }

    final amount = double.tryParse(priceController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      saving = true;
    });

    await PriceService.savePrice(
      Price(
        id: '',
        barcode: widget.product.barcode,
        storeId: store.id,
        store: store.name,
        province: store.province,
        city: store.city,
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
        title: const Text('Add Price'),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.product.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),
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
                        selectedStore?.toString() ??
                            'Search by name, address, or city',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: saving ? null : save,
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
            ),
    );
  }
}

class _StoreSearchScreen extends StatefulWidget {
  final List<Store> stores;

  const _StoreSearchScreen({required this.stores});

  @override
  State<_StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<_StoreSearchScreen> {
  final searchController = TextEditingController();
  late List<Store> filteredStores;

  @override
  void initState() {
    super.initState();
    filteredStores = List<Store>.from(widget.stores);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void filterStores(String value) {
    final queryTerms = value
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    setState(() {
      if (queryTerms.isEmpty) {
        filteredStores = List<Store>.from(widget.stores);
        return;
      }

      filteredStores = widget.stores.where((store) {
        final searchableText =
            '${store.name} ${store.storeName} ${store.chainName} '
                    '${store.address} ${store.city} '
                    '${store.province} ${store.postalCode}'
                .toLowerCase();

        return queryTerms.every(searchableText.contains);
      }).toList();
    });
  }

  void clearSearch() {
    searchController.clear();
    filterStores('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Store'),
        backgroundColor: _AddPriceScreenState.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: searchController,
                autofocus: true,
                onChanged: filterStores,
                textInputAction: TextInputAction.search,
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Search by store name, address, or city',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: clearSearch,
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: filteredStores.isEmpty
                  ? const Center(
                      child: Text(
                        'No stores found.',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filteredStores.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final store = filteredStores[index];

                        return ListTile(
                          leading: const Icon(Icons.store),
                          title: Text(store.displayName),
                          subtitle: store.locationLabel.isEmpty
                              ? null
                              : Text(store.locationLabel),
                          onTap: () {
                            Navigator.pop(context, store);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

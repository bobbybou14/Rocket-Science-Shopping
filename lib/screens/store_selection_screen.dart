import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/store.dart';
import '../service/shopping_session_service.dart';
import '../service/store_service.dart';

class StoreSelectionScreen extends StatefulWidget {
  final VoidCallback onStoreSelected;

  const StoreSelectionScreen({super.key, required this.onStoreSelected});

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  final TextEditingController searchController = TextEditingController();

  List<Store> stores = [];
  List<Store> filteredStores = [];

  Store? selectedStore;

  bool isLoading = true;
  String searchText = '';

  void startShopping() {
    final store = selectedStore;

    if (store == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a store before continuing.'),
        ),
      );
      return;
    }

    ShoppingSessionService.startSession(
      storeId: store.id,
      storeName: store.name,
    );

    widget.onStoreSelected();
  }

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  Future<void> loadStores() async {
    final loadedStores = await StoreService.getStores();

    if (!mounted) return;

    final activeStoreName = ShoppingSessionService.currentStoreName.trim();

    Store? activeStore;

    if (activeStoreName.isNotEmpty) {
      for (final store in loadedStores) {
        if (store.name.toLowerCase() == activeStoreName.toLowerCase()) {
          activeStore = store;
          break;
        }
      }
    }

    setState(() {
      stores = loadedStores;
      filteredStores = loadedStores;
      selectedStore = activeStore;
      isLoading = false;
    });
  }

  void filterStores(String value) {
    final query = value.toLowerCase().trim();
    final queryTerms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    setState(() {
      searchText = query;

      if (queryTerms.isEmpty) {
        filteredStores = stores;
        return;
      }

      filteredStores = stores.where((store) {
        final searchableText =
            '${store.name} ${store.storeName} ${store.chainName} '
                    '${store.address} ${store.city} '
                    '${store.province} ${store.postalCode}'
                .toLowerCase();

        return queryTerms.every(searchableText.contains);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Store')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(
                    Icons.storefront,
                    size: 76,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Where are you shopping today?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select your current store so Rocket Science Shopping can use the right prices and build an accurate running total.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: searchController,
                    onChanged: filterStores,
                    decoration: InputDecoration(
                      labelText: 'Search stores',
                      hintText: 'Store name, city, or province',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchText.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                searchController.clear();
                                filterStores('');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filteredStores.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.store_mall_directory_outlined,
                            size: 48,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No stores found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try another store name or city.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredStores.map(
                      (store) => _StoreOption(
                        store: store,
                        selected: selectedStore?.id == store.id,
                        onTap: () {
                          setState(() {
                            selectedStore = store;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: FilledButton.icon(
                onPressed: startShopping,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start Live Shopping'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

class _StoreOption extends StatelessWidget {
  final Store store;
  final bool selected;
  final VoidCallback onTap;

  const _StoreOption({
    required this.store,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: selected ? 3 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: selected
                    ? AppColors.primary
                    : Colors.grey.shade200,
                foregroundColor: selected ? Colors.white : Colors.grey.shade700,
                child: const Icon(Icons.store),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${store.city}, ${store.province}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (store.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        store.address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

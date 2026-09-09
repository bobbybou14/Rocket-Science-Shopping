import 'package:flutter/material.dart';

import '../models/store.dart';

class AdminPriceStoreSearchScreen extends StatefulWidget {
  final List<Store> stores;

  const AdminPriceStoreSearchScreen({super.key, required this.stores});

  @override
  State<AdminPriceStoreSearchScreen> createState() =>
      _AdminPriceStoreSearchScreenState();
}

class _AdminPriceStoreSearchScreenState
    extends State<AdminPriceStoreSearchScreen> {
  static const Color primaryRed = Color(0xFFD6001C);

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
        backgroundColor: primaryRed,
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

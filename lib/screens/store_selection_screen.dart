import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../service/shopping_session_service.dart';

class StoreSelectionScreen extends StatefulWidget {
  final VoidCallback onStoreSelected;

  const StoreSelectionScreen({super.key, required this.onStoreSelected});

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  static const List<String> stores = [
    'Walmart',
    'No Frills',
    'Food Basics',
    'Metro',
    'Sobeys',
    'Costco',
    'FreshCo',
    'Real Canadian Superstore',
    'Loblaws',
    'Zehrs',
    'Giant Tiger',
    'Independent Grocer',
    'Farm Boy',
    'Longo\'s',
    'Other',
  ];

  String? selectedStore;

  void startShopping() {
    final store = selectedStore;

    if (store == null || store.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a store before continuing.'),
        ),
      );
      return;
    }

    ShoppingSessionService.startSession(storeName: store);

    widget.onStoreSelected();
  }

  @override
  void initState() {
    super.initState();

    final activeStore = ShoppingSessionService.currentStoreName;

    if (activeStore.isNotEmpty) {
      selectedStore = activeStore;
    }
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
                    'Select your current store so SmartCart can use the right prices and build an accurate running total.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 28),
                  ...stores.map(
                    (store) => _StoreOption(
                      storeName: store,
                      selected: selectedStore == store,
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
}

class _StoreOption extends StatelessWidget {
  final String storeName;
  final bool selected;
  final VoidCallback onTap;

  const _StoreOption({
    required this.storeName,
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
                child: Text(
                  storeName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
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

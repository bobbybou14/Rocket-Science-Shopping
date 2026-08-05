import 'package:flutter/material.dart';

import '../models/shopping_trip.dart';
import '../models/product.dart';
import '../service/product_alias_service.dart';
import '../service/product_matcher_service.dart';
import '../service/product_suggestion_service.dart';
import '../service/receipt_parser_service.dart';
import '../service/receipt_processor_service.dart';
import '../widgets/create_product_dialog.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final ReceiptReviewDraft draft;

  const ReceiptReviewScreen({super.key, required this.draft});

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late ShoppingTrip _trip;
  late List<ShoppingTripItem> _items;

  @override
  void initState() {
    super.initState();

    _trip = widget.draft.shoppingTrip;
    _items = List<ShoppingTripItem>.from(_trip.items);
  }

  int get _itemsNeedingReview {
    return _items.where((item) => item.requiresReview).length;
  }

  double get _calculatedSubtotal {
    return _items.fold<double>(0, (total, item) => total + item.lineTotal);
  }

  double get _calculatedTotal {
    return _calculatedSubtotal + _trip.tax;
  }

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(3);
  }

  String _productDescription(Product product) {
    return [
      product.brand,
      product.size,
      product.category,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
  }

  String _confidenceLabel(double score) {
    if (score >= 85) return 'High confidence';
    if (score >= 75) return 'Medium confidence';
    return 'Low confidence';
  }

  IconData _confidenceIcon(double score) {
    if (score >= 85) return Icons.check_circle;
    if (score >= 75) return Icons.warning_amber_rounded;
    return Icons.error_outline;
  }

  Color _confidenceColor(BuildContext context, double score) {
    if (score >= 85) return Colors.green;
    if (score >= 75) return Colors.orange;
    return Theme.of(context).colorScheme.error;
  }

  void _replaceItem(int index, ShoppingTripItem updatedItem) {
    setState(() {
      _items[index] = updatedItem;
    });
  }

  void _toggleReviewed(int index) {
    final item = _items[index];

    _replaceItem(index, item.copyWith(requiresReview: !item.requiresReview));
  }

  Future<void> _chooseProduct(int index) async {
    final item = _items[index];
    final products = widget.draft.intelligenceResult.products;

    final receiptItem = ParsedReceiptItem(
      name: item.rawReceiptName,
      price: item.lineTotal,
      quantity: item.quantity,
      confidenceScore: item.confidenceScore,
    );

    final suggestions = ProductMatcherService.suggestMatches(
      receiptItem: receiptItem,
      products: products,
      limit: 5,
      minimumScore: 0,
    );

    final productSuggestionResult = ProductSuggestionService.buildSuggestion(
      receiptItemName: item.rawReceiptName,
      existingProducts: products,
    );

    final searchController = TextEditingController();

    Product? selectedProduct;
    var createdNewProduct = false;

    final result = await showDialog<Product>(
      context: context,
      builder: (dialogContext) {
        var searchQuery = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalizedQuery = searchQuery.trim().toLowerCase();

            final filteredProducts = normalizedQuery.isEmpty
                ? products
                : products.where((product) {
                    final searchableText = [
                      product.name,
                      product.brand,
                      product.category,
                      product.size,
                      product.barcode,
                    ].join(' ').toLowerCase();

                    return searchableText.contains(normalizedQuery);
                  }).toList();

            return AlertDialog(
              title: const Text('Choose Product'),
              content: SizedBox(
                width: 620,
                height: 600,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.rawReceiptName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select an existing product or create a new catalogue '
                      'product for this receipt line.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      autofocus: false,
                      enabled: products.isNotEmpty,
                      decoration: InputDecoration(
                        labelText: 'Search products',
                        hintText: products.isEmpty
                            ? 'The product catalogue is currently empty'
                            : 'Name, brand, category, size, or barcode',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  searchController.clear();

                                  setDialogState(() {
                                    searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: products.isEmpty
                          ? _buildNoCatalogueProductsMessage()
                          : normalizedQuery.isEmpty
                          ? _buildSuggestedProductList(
                              suggestions: suggestions,
                              selectedProduct: selectedProduct,
                              onSelected: (product) {
                                setDialogState(() {
                                  selectedProduct = product;
                                });
                              },
                            )
                          : _buildProductSearchResults(
                              products: filteredProducts,
                              selectedProduct: selectedProduct,
                              onSelected: (product) {
                                setDialogState(() {
                                  selectedProduct = product;
                                });
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_business_outlined),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Didn\'t find the correct product?',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Create it now and teach SmartCart how to '
                                  'recognize this receipt wording.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final createdProduct =
                                  await CreateProductDialog.show(
                                    context: dialogContext,
                                    suggestion:
                                        productSuggestionResult.suggestion,
                                    receiptItemName: item.rawReceiptName,
                                  );

                              if (createdProduct == null ||
                                  !dialogContext.mounted) {
                                return;
                              }

                              createdNewProduct = true;

                              Navigator.pop(dialogContext, createdProduct);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create New'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: selectedProduct == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, selectedProduct);
                        },
                  icon: const Icon(Icons.check),
                  label: const Text('Use Product'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();

    if (result == null || !mounted) return;

    _replaceItem(
      index,
      item.copyWith(
        product: result,
        barcode: result.barcode,
        confidenceScore: 100,
        requiresReview: false,
      ),
    );

    if (createdNewProduct) {
      final messenger = ScaffoldMessenger.of(context);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${result.name} was created and matched to this receipt item.',
            ),
          ),
        );

      return;
    }

    final shouldRemember = await _askToRememberAlias(
      receiptItemName: item.rawReceiptName,
      product: result,
    );

    if (shouldRemember == true) {
      final saved = await ProductAliasService.saveAlias(
        alias: item.rawReceiptName,
        product: result,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? '${result.name} selected and correction remembered.'
                : '${result.name} selected, but the correction could not be saved.',
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${result.name} selected.')));
  }

  Future<bool?> _askToRememberAlias({
    required String receiptItemName,
    required Product product,
  }) {
    if (receiptItemName.trim().isEmpty || product.barcode.isEmpty) {
      return Future.value(false);
    }

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remember This Correction?'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SmartCart can use this correction to recognize the same '
                  'receipt wording automatically in the future.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Receipt wording',
                  style: Theme.of(dialogContext).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  receiptItemName,
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Icon(Icons.arrow_downward),
                const SizedBox(height: 16),
                Text(
                  'Catalogue product',
                  style: Theme.of(dialogContext).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_productDescription(product).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_productDescription(product)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Not Now'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.psychology_outlined),
              label: const Text('Remember'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoCatalogueProductsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'No catalogue products are available yet.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a new product below to add it to the SmartCart '
              'catalogue and match it to this receipt item.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedProductList({
    required List<ProductMatchResult> suggestions,
    required Product? selectedProduct,
    required ValueChanged<Product> onSelected,
  }) {
    if (suggestions.isEmpty) {
      return const Center(
        child: Text(
          'No automatic suggestions were found.\n'
          'Use the search box to find a product.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      children: [
        Text(
          'Suggested matches',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...suggestions.map((suggestion) {
          final product = suggestion.product;

          if (product == null) {
            return const SizedBox.shrink();
          }

          return _ProductOptionTile(
            product: product,
            confidenceScore: suggestion.confidenceScore,
            selected: selectedProduct?.barcode == product.barcode,
            onTap: () => onSelected(product),
          );
        }),

        const SizedBox(height: 12),

        const Text(
          'Search the full catalogue above if the correct product is not listed.',
        ),
      ],
    );
  }

  Widget _buildProductSearchResults({
    required List<Product> products,
    required Product? selectedProduct,
    required ValueChanged<Product> onSelected,
  }) {
    if (products.isEmpty) {
      return const Center(child: Text('No products match your search.'));
    }

    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = products[index];

        return _ProductOptionTile(
          product: product,
          selected: selectedProduct?.barcode == product.barcode,
          onTap: () => onSelected(product),
        );
      },
    );
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];

    final nameController = TextEditingController(text: item.rawReceiptName);

    final quantityController = TextEditingController(
      text: _formatQuantity(item.quantity),
    );

    final lineTotalController = TextEditingController(
      text: item.lineTotal.toStringAsFixed(2),
    );

    final result = await showDialog<ShoppingTripItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Receipt Item'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Receipt item name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: lineTotalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Line total',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final quantity = double.tryParse(
                  quantityController.text.trim(),
                );
                final lineTotal = double.tryParse(
                  lineTotalController.text.trim(),
                );

                if (name.isEmpty ||
                    quantity == null ||
                    quantity <= 0 ||
                    lineTotal == null ||
                    lineTotal < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid name, quantity, and line total.',
                      ),
                    ),
                  );
                  return;
                }

                final unitPrice = lineTotal / quantity;

                Navigator.pop(
                  dialogContext,
                  item.copyWith(
                    rawReceiptName: name,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    lineTotal: lineTotal,
                    requiresReview: false,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
    lineTotalController.dispose();

    if (result == null || !mounted) return;

    _replaceItem(index, result);
  }

  Future<void> _addItem() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final lineTotalController = TextEditingController();

    final result = await showDialog<ShoppingTripItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Receipt Item'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the missing item exactly as it appears on the receipt.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Receipt item name',
                      hintText: 'Example: Organic Bananas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: '1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: lineTotalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Line total',
                      hintText: '0.00',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();

                final quantity = double.tryParse(
                  quantityController.text.trim().replaceAll(',', '.'),
                );

                final lineTotal = double.tryParse(
                  lineTotalController.text
                      .trim()
                      .replaceAll('\$', '')
                      .replaceAll(',', '.'),
                );

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter the receipt item name.'),
                    ),
                  );
                  return;
                }

                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid quantity greater than zero.',
                      ),
                    ),
                  );
                  return;
                }

                if (lineTotal == null || lineTotal < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a valid line total.')),
                  );
                  return;
                }

                final unitPrice = lineTotal / quantity;

                Navigator.pop(
                  dialogContext,
                  ShoppingTripItem(
                    id: '',
                    shoppingTripId: _trip.id,
                    rawReceiptName: name,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    lineTotal: lineTotal,
                    confidenceScore: 100,
                    requiresReview: false,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
    lineTotalController.dispose();

    if (result == null || !mounted) return;

    setState(() {
      _items.add(result);
    });

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              Expanded(child: Text('${result.rawReceiptName} added.')),
              TextButton(
                onPressed: () {
                  if (!mounted) return;

                  setState(() {
                    _items.remove(result);
                  });

                  messenger.hideCurrentSnackBar();
                },
                child: const Text('Undo'),
              ),
            ],
          ),
        ),
      );
  }

  void _removeItem(int index) {
    final removedItem = _items[index];

    setState(() {
      _items.removeAt(index);
    });

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              Expanded(child: Text('${removedItem.rawReceiptName} removed.')),
              TextButton(
                onPressed: () {
                  if (!mounted) return;

                  setState(() {
                    final insertIndex = index.clamp(0, _items.length);
                    _items.insert(insertIndex, removedItem);
                  });

                  messenger.hideCurrentSnackBar();
                },
                child: const Text('Undo'),
              ),
            ],
          ),
        ),
      );
  }

  void _markAllReviewed() {
    setState(() {
      _items = _items
          .map((item) => item.copyWith(requiresReview: false))
          .toList();
    });
  }

  void _confirmReceipt() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A receipt must contain at least one item.'),
        ),
      );
      return;
    }

    if (_itemsNeedingReview > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Review the remaining $_itemsNeedingReview item(s) first.',
          ),
        ),
      );
      return;
    }

    final reviewedTrip = _trip.copyWith(
      subtotal: _calculatedSubtotal,
      total: _calculatedTotal,
      processingStatus: 'verified',
      items: _items,
    );

    Navigator.pop(context, reviewedTrip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Receipt')),
      body: Column(
        children: [
          _buildSummary(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildItemCard(index, _items[index]);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSummary() {
    final reviewCount = _itemsNeedingReview;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.storefront),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _trip.storeName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${_items.length} item${_items.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Calculated subtotal',
                    value: _formatMoney(_calculatedSubtotal),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Updated total',
                    value: _formatMoney(_calculatedTotal),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Needs review',
                    value: reviewCount.toString(),
                  ),
                ),
              ],
            ),
            if (reviewCount > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _markAllReviewed,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Accept All Items'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, ShoppingTripItem item) {
    final confidenceColor = _confidenceColor(context, item.confidenceScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.requiresReview ? Icons.pending_actions : Icons.verified,
                  color: item.requiresReview ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.rawReceiptName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editItem(index);
                        break;

                      case 'chooseProduct':
                        _chooseProduct(index);
                        break;

                      case 'remove':
                        _removeItem(index);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit Receipt Details'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'chooseProduct',
                      child: ListTile(
                        leading: Icon(Icons.shopping_bag_outlined),
                        title: Text('Choose Product'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Remove'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: item.product == null
                  ? Row(
                      children: [
                        const Icon(Icons.link_off),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No catalogue product selected',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _chooseProduct(index),
                          child: const Text('Choose'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_productDescription(item.product!).isNotEmpty)
                                Text(
                                  _productDescription(item.product!),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _chooseProduct(index),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.numbers,
                  label: 'Qty ${_formatQuantity(item.quantity)}',
                ),
                _InfoChip(
                  icon: Icons.sell_outlined,
                  label: '${_formatMoney(item.unitPrice)} each',
                ),
                _InfoChip(
                  icon: Icons.receipt,
                  label: _formatMoney(item.lineTotal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _confidenceIcon(item.confidenceScore),
                  size: 20,
                  color: confidenceColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_confidenceLabel(item.confidenceScore)} '
                    '(${item.confidenceScore.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _toggleReviewed(index),
                  icon: Icon(item.requiresReview ? Icons.check : Icons.undo),
                  label: Text(item.requiresReview ? 'Accept' : 'Review Again'),
                ),
              ],
            ),
            if (item.product == null) ...[
              const SizedBox(height: 8),
              const Text(
                'No product match was found. Choose a catalogue '
                'product, accept this receipt item, or edit its details.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72),
            SizedBox(height: 16),
            Text(
              'No receipt items remain.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Material(
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _itemsNeedingReview == 0
                          ? _confirmReceipt
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _itemsNeedingReview == 0
                            ? 'Confirm Receipt'
                            : '$_itemsNeedingReview Item(s) Need Review',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _ProductOptionTile extends StatelessWidget {
  final Product product;
  final double? confidenceScore;
  final bool selected;
  final VoidCallback onTap;

  const _ProductOptionTile({
    required this.product,
    required this.selected,
    required this.onTap,
    this.confidenceScore,
  });

  String get description {
    return [
      product.brand,
      product.size,
      product.category,
      if (product.barcode.isNotEmpty) product.barcode,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return RadioGroup<bool>(
      groupValue: selected,
      onChanged: (value) {
        if (value == true) {
          onTap();
        }
      },
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (confidenceScore != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '${confidenceScore!.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: confidenceScore! >= 75
                            ? Colors.green
                            : confidenceScore! >= 45
                            ? Colors.orange
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const Radio<bool>(value: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../service/basket_comparison_service.dart';
import '../service/grocery_list_service.dart';
import '../service/product_service.dart';
import 'basket_comparison_screen.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  List<GroceryListItem> _items = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await GroceryListService.getItems();
      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load your grocery list: $error';
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await action();
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (mounted) _showMessage('Unable to save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editItem({GroceryListItem? item}) async {
    var name = item?.name ?? '';
    var quantityText = item == null ? '1' : _quantity(item.quantity);
    final formKey = GlobalKey<FormState>();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? 'Add Grocery Item' : 'Edit Grocery Item'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  onChanged: (value) => name = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an item name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: quantityText,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) => quantityText = value,
                  validator: (value) {
                    final quantity = double.tryParse(value?.trim() ?? '');
                    return quantity == null ||
                            !quantity.isFinite ||
                            quantity <= 0
                        ? 'Enter a quantity greater than zero.'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) return;

    final quantity = double.parse(quantityText.trim());

    await _save(
      () => item == null
          ? GroceryListService.addManualItem(name: name, quantity: quantity)
          : GroceryListService.updateItem(
              id: item.id,
              name: name,
              quantity: quantity,
            ),
    );
  }

  Future<void> _addCatalogueProduct() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const _GroceryProductSearchScreen()),
    );

    if (product == null || !mounted) return;

    await _save(() => GroceryListService.addProduct(product: product));
  }

  Future<void> _clearChecked() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove checked items?'),
        content: const Text('Unchecked items will stay on your grocery list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _save(GroceryListService.clearCheckedItems);
    }
  }

  Future<void> _compare() async {
    final pending = _items.where((item) => !item.isChecked).toList();
    final linked = pending.where((item) => item.product != null).toList();
    final unlinkedCount = pending.length - linked.length;

    if (linked.isEmpty) {
      _showMessage(
        'Add a catalogue product to compare prices. '
        'Typed items stay on your list as reminders.',
      );
      return;
    }

    if (unlinkedCount > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Compare catalogue items?'),
          content: Text(
            '$unlinkedCount unchecked item(s) are not linked to catalogue '
            'products and will be excluded from this comparison.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BasketComparisonScreen(
          initialItems: linked
              .map(
                (item) => BasketItemRequest(
                  product: item.product!,
                  quantity: item.quantity,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _quantity(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  @override
  Widget build(BuildContext context) {
    final pendingCount = _items.where((item) => !item.isChecked).length;
    final hasChecked = _items.any((item) => item.isChecked);
    final busy = _loading || _saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Grocery List'),
        actions: [
          IconButton(
            tooltip: 'Refresh list',
            onPressed: busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Remove checked items',
            onPressed: busy || !hasChecked ? null : _clearChecked,
            icon: const Icon(Icons.playlist_remove),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$pendingCount item${pendingCount == 1 ? '' : 's'} still needed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: busy ? null : _addCatalogueProduct,
                      icon: const Icon(Icons.search),
                      label: const Text('Find Product'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _editItem(),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Type an Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Catalogue products can be compared across stores. '
                  'Typed items are saved as reminders.',
                ),
              ],
            ),
          ),
          if (_saving) const LinearProgressIndicator(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Your grocery list is empty. '
                        'Find a product or type your first item.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];

                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: item.isChecked,
                            onChanged: busy
                                ? null
                                : (value) => _save(
                                    () => GroceryListService.setChecked(
                                      id: item.id,
                                      isChecked: value ?? false,
                                    ),
                                  ),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              decoration: item.isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            'Quantity: ${_quantity(item.quantity)}'
                            '\n${item.product == null ? 'Reminder — no catalogue link' : 'Catalogue product'}',
                          ),
                          onTap: busy ? null : () => _editItem(item: item),
                          trailing: IconButton(
                            tooltip: 'Remove item',
                            onPressed: busy
                                ? null
                                : () => _save(
                                    () =>
                                        GroceryListService.deleteItem(item.id),
                                  ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy || _error != null || pendingCount == 0
                      ? null
                      : _compare,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Compare Unchecked Products'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroceryProductSearchScreen extends StatefulWidget {
  const _GroceryProductSearchScreen();

  @override
  State<_GroceryProductSearchScreen> createState() =>
      _GroceryProductSearchScreenState();
}

class _GroceryProductSearchScreenState
    extends State<_GroceryProductSearchScreen> {
  final _controller = TextEditingController();
  final List<Product> _products = [];
  String _query = '';
  String? _error;
  bool _loading = false;
  bool _hasMore = false;
  int _offset = 0;
  int _requestId = 0;

  Future<void> _search({bool append = false}) async {
    if (append && (_loading || !_hasMore)) return;

    final query = append ? _query : _controller.text.trim();
    if (query.isEmpty) return;

    final requestId = ++_requestId;
    final offset = append ? _offset : 0;

    setState(() {
      _loading = true;
      _error = null;

      if (!append) {
        _query = query;
        _products.clear();
        _hasMore = false;
        _offset = 0;
      }
    });

    try {
      final response = await ProductService.searchProducts(
        search: query,
        offset: offset,
        pageSize: 50,
      );

      if (!mounted || requestId != _requestId) return;

      final page = response.take(50).toList();

      setState(() {
        final known = _products.map((product) => product.barcode).toSet();
        _products.addAll(page.where((product) => known.add(product.barcode)));
        _offset = offset + page.length;
        _hasMore = response.length > 50;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = 'Unable to search products: $error';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Grocery Product')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Name, brand or barcode',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: () => _search(),
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: _products.isEmpty
                ? Center(
                    child: Text(
                      _loading
                          ? 'Searching...'
                          : _query.isEmpty
                          ? 'Enter a search and tap the search icon.'
                          : 'No products found.',
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _products.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _products.length) {
                        return TextButton(
                          onPressed: _loading
                              ? null
                              : () => _search(append: true),
                          child: const Text('Load More'),
                        );
                      }

                      final product = _products[index];
                      final description = [
                        product.brand,
                        product.name,
                        product.size,
                      ].where((value) => value.trim().isNotEmpty).join(' ');

                      return ListTile(
                        title: Text(description),
                        subtitle: Text(product.barcode),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(context, product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
